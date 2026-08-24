import Foundation
import UIKit
import Vision
import CoreMedia
import CoreVideo

/// Gestionnaire de Reconnaissance Visuelle sur Appareil (Vision Framework & CoreML)
/// - Détection d'objets intérieurs courants (bouteille, lit, armoire, chemise, chaise, table, ordinateur, etc.)
/// - Traitement temps réel de CVPixelBuffer et UIImage
/// - Compatible 100% de iOS 12 à iOS 17+ avec optimisations puces A7 -> A16/A17
public final class VisionManager {
    
    public static let shared = VisionManager()
    
    public struct RecognitionResult {
        public let label: String
        public let frenchLabel: String
        public let confidence: Float
        public let spokenPhrase: String
        public let detectedText: String
    }
    
    // Dictionnaire enrichi pour les objets d'intérieur
    private let indoorDictionary: [String: (french: String, article: String)] = [
        "bottle": ("bouteille", "une"),
        "water bottle": ("bouteille d'eau", "une"),
        "wine bottle": ("bouteille", "une"),
        "bed": ("lit", "un"),
        "wardrobe": ("armoire", "une"),
        "closet": ("placard", "un"),
        "cupboard": ("armoire", "une"),
        "shirt": ("chemise", "une"),
        "jersey": ("t-shirt", "un"),
        "t-shirt": ("t-shirt", "un"),
        "chair": ("chaise", "une"),
        "folding chair": ("chaise pliante", "une"),
        "rocking chair": ("fauteuil à bascule", "un"),
        "armchair": ("fauteuil", "un"),
        "couch": ("canapé", "un"),
        "sofa": ("canapé", "un"),
        "table": ("table", "une"),
        "desk": ("bureau", "un"),
        "dining table": ("table à manger", "une"),
        "cup": ("tasse", "une"),
        "coffee cup": ("tasse de café", "une"),
        "mug": ("mug", "un"),
        "laptop": ("ordinateur portable", "un"),
        "computer": ("ordinateur", "un"),
        "cellular telephone": ("téléphone", "un"),
        "cellphone": ("smartphone", "un"),
        "mobile phone": ("smartphone", "un"),
        "phone": ("téléphone", "un"),
        "screen": ("écran", "un"),
        "television": ("téléviseur", "un"),
        "book": ("livre", "un"),
        "notebook": ("cahier", "un"),
        "backpack": ("sac à dos", "un"),
        "shoes": ("chaussures", "des"),
        "pillow": ("oreiller", "un"),
        "lamp": ("lampe", "une"),
        "door": ("porte", "une"),
        "window": ("fenêtre", "une")
    ]
    
    private init() {}
    
    // MARK: - Analyse de CVPixelBuffer (Caméra / ReplayKit)
    
    public func analyzePixelBuffer(
        _ pixelBuffer: CVPixelBuffer,
        completion: @escaping (RecognitionResult) -> Void
    ) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        performVisionRequests(using: handler, completion: completion)
    }
    
    // MARK: - Analyse d'UIImage
    
    public func analyzeImage(
        _ image: UIImage,
        completion: @escaping (RecognitionResult) -> Void
    ) {
        guard let cgImage = image.cgImage else {
            completion(fallbackResult())
            return
        }
        let orientation = cgImageOrientation(from: image.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        performVisionRequests(using: handler, completion: completion)
    }
    
    // MARK: - Pipeline de Requêtes Vision
    
    private func performVisionRequests(
        using handler: VNImageRequestHandler,
        completion: @escaping (RecognitionResult) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var detectedText = ""
            var bestClassification: (label: String, confidence: Float)?
            
            // 1. Requête OCR de Texte (iOS 13+)
            let textRequest: VNRequest?
            if #available(iOS 13.0, *) {
                let req = VNRecognizeTextRequest { request, error in
                    guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else { return }
                    let texts = observations.compactMap { $0.topCandidates(1).first?.string }
                    detectedText = texts.joined(separator: " ")
                }
                req.recognitionLevel = .fast
                req.recognitionLanguages = ["fr-FR", "en-US"]
                textRequest = req
            } else {
                textRequest = nil
            }
            
            // 2. Requête de Classification d'Images & Objets (iOS 14+)
            let classifyRequest: VNRequest?
            if #available(iOS 14.0, *) {
                let req = VNClassifyImageRequest { request, error in
                    guard let observations = request.results as? [VNClassificationObservation], error == nil else { return }
                    
                    // Trouver la meilleure correspondance avec notre catalogue d'objets intérieurs
                    for obs in observations where obs.confidence > 0.15 {
                        let lower = obs.identifier.lowercased()
                        for key in self.indoorDictionary.keys {
                            if lower.contains(key) {
                                bestClassification = (key, obs.confidence)
                                break
                            }
                        }
                        if bestClassification != nil { break }
                    }
                    
                    // Fallback sur le premier objet classifié si aucun objet spécifique trouvé
                    if bestClassification == nil, let top = observations.first, top.confidence > 0.3 {
                        bestClassification = (top.identifier, top.confidence)
                    }
                }
                classifyRequest = req
            } else {
                classifyRequest = nil
            }
            
            var requests: [VNRequest] = []
            if let tr = textRequest { requests.append(tr) }
            if let cr = classifyRequest { requests.append(cr) }
            
            do {
                if !requests.isEmpty {
                    try handler.perform(requests)
                }
            } catch {
                print("⚠️ [VisionManager] Erreur Vision: \(error.localizedDescription)")
            }
            
            // Formatage du résultat
            let rawLabel = bestClassification?.label.lowercased() ?? "inconnu"
            let confidence = bestClassification?.confidence ?? 0.0
            
            let frenchEntry = self.indoorDictionary[rawLabel]
            let frenchLabel = frenchEntry?.french ?? rawLabel
            let article = frenchEntry?.article ?? "un"
            
            let spokenPhrase: String
            if !detectedText.isEmpty {
                spokenPhrase = "Je vois écrit : « \(detectedText) »"
            } else if frenchLabel != "inconnu" {
                spokenPhrase = "C'est \(article) \(frenchLabel) !"
            } else {
                spokenPhrase = "Je regarde ce que tu me montres."
            }
            
            let result = RecognitionResult(
                label: rawLabel,
                frenchLabel: frenchLabel,
                confidence: confidence,
                spokenPhrase: spokenPhrase,
                detectedText: detectedText
            )
            
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    private func fallbackResult() -> RecognitionResult {
        return RecognitionResult(
            label: "inconnu",
            frenchLabel: "inconnu",
            confidence: 0.0,
            spokenPhrase: "Je regarde ce que tu me montres.",
            detectedText: ""
        )
    }
    
    private func cgImageOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
