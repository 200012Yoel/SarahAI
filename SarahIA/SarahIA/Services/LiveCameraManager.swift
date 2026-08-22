import Foundation
import UIKit
import AVFoundation
import CoreMedia
import CoreVideo

/// Gestionnaire de session Caméra Live Ultra-Optimisé & Léger :
/// - Compatible 100% avec les appareils d'entrée de gamme (iPhone 5S, 6, 7, 8 jusqu'à iPhone 14/15)
/// - Résolution 480p/720p adaptative pour éviter tout pic RAM / Crash OOM sur 1 Go de RAM
/// - Thread dédié en arrière-plan pour la capture et le traitement des tampons CMSampleBuffer
/// - Déchargement automatique et immédiat des tampons mémoire via autoreleasepool
public final class LiveCameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public static let shared = LiveCameraManager()
    
    // MARK: - Propriétés AVCapture
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.sarahia.camera.sessionQueue", qos: .userInitiated)
    private let videoDataQueue = DispatchQueue(label: "com.sarahia.camera.videoDataQueue", qos: .userInitiated)
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    private var isSessionConfigured = false
    private var lastFrameTime: TimeInterval = 0
    private let frameThrottleInterval: TimeInterval = 0.4 // Max 2.5 fps pour l'analyse IA
    
    private var onFrameCaptured: ((UIImage) -> Void)?
    
    // MARK: - Initialisation
    private override init() {
        super.init()
    }
    
    // MARK: - Configuration Sécurisée de la Session
    
    /// Prépare la session caméra avec une résolution optimisée pour iPhone 5S (480p/720p)
    public func setupSession(previewView: UIView? = nil, completion: @escaping (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            if self.isSessionConfigured {
                if let view = previewView {
                    DispatchQueue.main.async {
                        self.attachPreview(to: view)
                        completion(true)
                    }
                } else {
                    DispatchQueue.main.async { completion(true) }
                }
                return
            }
            
            self.captureSession.beginConfiguration()
            
            // 1. Choix du preset basse consommation mémoire (480p / 720p)
            if self.captureSession.canSetSessionPreset(.vga640x480) {
                self.captureSession.sessionPreset = .vga640x480
            } else if self.captureSession.canSetSessionPreset(.medium) {
                self.captureSession.sessionPreset = .medium
            } else if self.captureSession.canSetSessionPreset(.hd1280x720) {
                self.captureSession.sessionPreset = .hd1280x720
            }
            
            // 2. Sélection de la caméra arrière par défaut
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                    ?? AVCaptureDevice.default(for: .video) else {
                self.captureSession.commitConfiguration()
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                    self.videoDeviceInput = input
                }
            } catch {
                print("❌ [LiveCameraManager] Erreur configuration caméra: \(error)")
                self.captureSession.commitConfiguration()
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // 3. Configuration de la sortie vidéo avec abandon automatique des images en retard
            self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
            self.videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoDataQueue)
            
            if self.captureSession.canAddOutput(self.videoDataOutput) {
                self.captureSession.addOutput(self.videoDataOutput)
            }
            
            self.captureSession.commitConfiguration()
            self.isSessionConfigured = true
            
            DispatchQueue.main.async {
                if let view = previewView {
                    self.attachPreview(to: view)
                }
                completion(true)
            }
        }
    }
    
    // MARK: - Contrôle de la Session
    
    public func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
    
    public func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }
    
    // MARK: - Aperçu Vidéo (Preview)
    
    private func attachPreview(to view: UIView) {
        if previewLayer == nil {
            let layer = AVCaptureVideoPreviewLayer(session: captureSession)
            layer.videoGravity = .resizeAspectFill
            self.previewLayer = layer
        }
        
        guard let pLayer = previewLayer else { return }
        pLayer.frame = view.bounds
        if pLayer.superlayer == nil {
            view.layer.insertSublayer(pLayer, at: 0)
        }
    }
    
    public func updatePreviewLayout(bounds: CGRect) {
        DispatchQueue.main.async { [weak self] in
            self?.previewLayer?.frame = bounds
        }
    }
    
    // MARK: - Capture d'une Image Fixe Instantanée (Still Frame)
    
    public func captureSnapshot(completion: @escaping (UIImage?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            self.onFrameCaptured = { [weak self] image in
                self?.onFrameCaptured = nil
                DispatchQueue.main.async {
                    completion(image)
                }
            }
        }
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate (Traitement Léger)
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        autoreleasepool {
            let now = CACurrentMediaTime()
            let isSnapshotRequested = (onFrameCaptured != nil)
            
            // Si pas de snapshot et que le throttle n'est pas écoulé -> libération immédiate du buffer
            if !isSnapshotRequested && (now - lastFrameTime < frameThrottleInterval) {
                return
            }
            
            lastFrameTime = now
            
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            // Conversion optimisée CVPixelBuffer -> CIImage -> CGImage
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            let context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
            
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
            let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
            
            // Déclenchement du callback de snapshot
            if let callback = onFrameCaptured {
                onFrameCaptured = nil
                callback(uiImage)
            }
        }
    }
}
