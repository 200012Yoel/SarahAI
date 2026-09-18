import Foundation
import Speech
import AVFoundation
#if canImport(Combine)
import Combine
#endif

/// État de la reconnaissance vocale Apple native
public enum SpeechRecognizerState: Equatable {
    case idle
    case listening
    case processing
    case error(String)
}

/// Gestionnaire de Reconnaissance Vocale 100% Gratuit, Local et Continu basé sur Apple Speech.framework (`SFSpeechRecognizer`).
public final class AppleSpeechRecognizer: NSObject, SFSpeechRecognizerDelegate {
    
    public static let shared = AppleSpeechRecognizer()
    
    public private(set) var state: SpeechRecognizerState = .idle {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("AppleSpeechRecognizerStateChanged"), object: nil)
            }
        }
    }
    
    public private(set) var isListening: Bool = false {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("AppleSpeechRecognizerListeningChanged"), object: nil)
            }
        }
    }
    
    public private(set) var currentLiveText: String = ""
    public private(set) var micEnergyLevel: Float = 0.0
    
    public var onPartialTranscription: ((String) -> Void)?
    public var onFinalTranscription: ((String) -> Void)?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Détection automatique de silence pour valider la fin de la phrase
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 1.3 // Secondes de pause pour valider la question
    private var hasDetectedSpeechInCurrentSession: Bool = false

    // Limite la télémétrie du niveau micro à ~15 FPS. Le callback audio tourne
    // beaucoup plus vite et ne doit jamais inonder le thread principal.
    private var lastEnergyPublishTime: TimeInterval = 0
    private let energyPublishInterval: TimeInterval = 1.0 / 15.0
    
    private override init() {
        super.init()
        speechRecognizer?.delegate = self
    }
    
    // MARK: - Demande d'Autorisation Micro + Reconnaissance Vocale
    
    public func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                        DispatchQueue.main.async {
                            completion(allowed)
                        }
                    }
                default:
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - Démarrage de l'Écoute
    
    public func startListening() {
        guard !isListening else { return }
        
        // Arrêter toute synthèse vocale avant d'écouter, y compris la voix du
        // chat principal qui passe par AgentVoiceManager.
        TTSManager.shared.stop()
        SpeechManager.shared.stopSpeaking()
        if #available(iOS 13.0, *) {
            TTSService.shared.stopSpeaking()
        }
        
        // Annuler toute tâche de reconnaissance précédente
        stopListening()
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            state = .error("Reconnaissance vocale non disponible")
            return
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Pendant l'écoute, on n'a besoin que de l'entrée micro. Éviter
            // .playAndRecord + .duckOthers empêche Sarah de modifier inutilement
            // le volume/routage audio du reste de l'iPhone.
            try audioSession.setCategory(.record, mode: .measurement, options: [.allowBluetooth])
            try audioSession.setPreferredIOBufferDuration(0.046)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            state = .error("Erreur session audio: \(error.localizedDescription)")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        
        request.shouldReportPartialResults = true
        if #available(iOS 13.0, *) {
            request.requiresOnDeviceRecognition = false
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, when) in
            self?.recognitionRequest?.append(buffer)
            self?.calculateAudioEnergy(buffer: buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isListening = true
            state = .listening
            currentLiveText = ""
            hasDetectedSpeechInCurrentSession = false
            HapticService.shared.speechStarted()
        } catch {
            state = .error("Impossible de démarrer l'AudioEngine: \(error.localizedDescription)")
            stopListening()
            return
        }
        
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] (result, error) in
            guard let self = self else { return }
            
            if let result = result {
                let transcribedString = result.bestTranscription.formattedString
                self.currentLiveText = transcribedString
                self.hasDetectedSpeechInCurrentSession = true
                self.onPartialTranscription?(transcribedString)
                
                // Réinitialise le timer de silence à chaque mot détecté
                self.resetSilenceTimer()
                
                if result.isFinal {
                    self.finalizeTranscription(transcribedString)
                }
            }
            
            if let error = error {
                let nsError = error as NSError
                // 216 = Annulation normale par l'utilisateur
                if nsError.code != 216 && self.isListening {
                    self.state = .error(error.localizedDescription)
                }
                self.stopListening()
            }
        }
    }
    
    // MARK: - Arrêt de l'Écoute
    
    public func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        if isListening {
            isListening = false
            state = .idle
            micEnergyLevel = 0.0
            HapticService.shared.speechFinished()
        }

        // Très important : rendre immédiatement la session audio à iOS.
        // Sans cela, le téléphone peut rester dans une route micro/mesure,
        // perturber le son système ou conserver les autres apps atténuées.
        let session = AVAudioSession.sharedInstance()
        if !MultiAgentVoiceManager.shared.isSpeaking && !SpeechManager.shared.isSpeaking {
            do {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("⚠️ [AppleSpeechRecognizer] Impossible de désactiver la session audio: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Détection Automatique de Silence & Finalisation
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            guard let self = self, self.isListening, self.hasDetectedSpeechInCurrentSession else { return }
            let finalText = self.currentLiveText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !finalText.isEmpty {
                self.finalizeTranscription(finalText)
            }
        }
    }
    
    private func finalizeTranscription(_ text: String) {
        let textToSend = text
        stopListening()
        state = .processing
        HapticService.shared.notificationSuccess()
        onFinalTranscription?(textToSend)
    }
    
    // MARK: - Mesure de l'Énergie Vocale pour l'Animation de l'Onde
    
    private func calculateAudioEnergy(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = UInt(buffer.frameLength)
        
        var sum: Float = 0.0
        for i in 0..<Int(frameLength) {
            let sample = channelData[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        let normalized = min(1.0, max(0.0, rms * 10.0))

        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastEnergyPublishTime >= energyPublishInterval else { return }
        lastEnergyPublishTime = now

        DispatchQueue.main.async {
            guard self.isListening else { return }
            self.micEnergyLevel = normalized
            NotificationCenter.default.post(
                name: NSNotification.Name("AppleSpeechRecognizerEnergyChanged"),
                object: nil
            )
        }
    }
    
    // MARK: - SFSpeechRecognizerDelegate
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            stopListening()
            state = .error("Reconnaissance vocale temporairement indisponible")
        }
    }
}

#if canImport(Combine)
@available(iOS 13.0, *)
public final class ObservableSpeechRecognizer: ObservableObject {
    public static let shared = ObservableSpeechRecognizer()
    
    @Published public var isListening: Bool = AppleSpeechRecognizer.shared.isListening
    @Published public var currentLiveText: String = AppleSpeechRecognizer.shared.currentLiveText
    @Published public var micEnergyLevel: Float = AppleSpeechRecognizer.shared.micEnergyLevel
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        NotificationCenter.default.publisher(for: NSNotification.Name("AppleSpeechRecognizerListeningChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isListening = AppleSpeechRecognizer.shared.isListening
                self?.currentLiveText = AppleSpeechRecognizer.shared.currentLiveText
                self?.micEnergyLevel = AppleSpeechRecognizer.shared.micEnergyLevel
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("AppleSpeechRecognizerEnergyChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.micEnergyLevel = AppleSpeechRecognizer.shared.micEnergyLevel
                self?.currentLiveText = AppleSpeechRecognizer.shared.currentLiveText
            }
            .store(in: &cancellables)
    }
}
#endif
