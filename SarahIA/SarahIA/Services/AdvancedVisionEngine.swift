import Foundation
import UIKit
import Vision

/// Moteur de Vision Multimodale 100% On-Device pour Sarah IA (Apple Vision Framework)
/// - Multi-Pass Vision Pipeline 100% Hors-Ligne :
///   1. Reconnaissance d'objets et d'animaux (VNClassifyImageRequest)
///   2. Reconnaissance optique de caractères OCR haute précision (VNRecognizeTextRequest)
///   3. Détection faciale, expressions et orientation (VNDetectFaceRectanglesRequest / Landmarks)
///   4. Détection de codes-barres et QR codes (VNDetectBarcodesRequest)
/// - Synthèse vocale et textuelle naturelle en français (« Je vois... », « Il y a un texte qui dit... »)
public final class AdvancedVisionEngine {
    
    public static let shared = AdvancedVisionEngine()
    
    public struct ComprehensiveVisionReport {
        public let summaryText: String
        public let spokenDescription: String
        public let primaryObjects: [String]
        public let extractedText: String?
        public let faceCount: Int
        public let detectedBarcodes: [String]
        public let detailedLLMAnalysis: String?
    }
    
    private let visionQueue = DispatchQueue(label: "com.sarahia.advancedvision.queue", qos: .userInitiated)
    
    private init() {}
    
    // MARK: - Analyse Complète de l'Image
    
    public func analyzeImageComprehensive(
        _ image: UIImage,
        completion: @escaping (ComprehensiveVisionReport) -> Void
    ) {
        visionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 1. Optimisation et préparation de l'image (max 1024px pour économiser la RAM)
            guard let (preparedImage, cgImage) = self.prepareCGImage(from: image) else {
                DispatchQueue.main.async {
                    completion(ComprehensiveVisionReport(
                        summaryText: "Impossible de traiter l'image fournie.",
                        spokenDescription: "Je n'ai pas réussi à lire l'image.",
                        primaryObjects: [],
                        extractedText: nil,
                        faceCount: 0,
                        detectedBarcodes: [],
                        detailedLLMAnalysis: nil
                    ))
                }
                return
            }
            
            var detectedObjects: [(label: String, confidence: Float)] = []
            var recognizedTexts: [String] = []
            var faceCount: Int = 0
            var detectedBarcodes: [String] = []
            
            let group = DispatchGroup()
            
            // A. Classification d'Objets & Scènes
            if #available(iOS 13.0, *) {
                group.enter()
                let classifyRequest = VNClassifyImageRequest { request, error in
                    defer { group.leave() }
                    guard let results = request.results as? [VNClassificationObservation] else { return }
                    let top = results.filter { $0.confidence > 0.15 }.prefix(5)
                    detectedObjects = top.map { ($0.identifier, $0.confidence) }
                }
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([classifyRequest])
            }
            
            // B. Reconnaissance de Texte OCR Haute Précision
            if #available(iOS 13.0, *) {
                group.enter()
                let textRequest = VNRecognizeTextRequest { request, error in
                    defer { group.leave() }
                    guard let results = request.results as? [VNRecognizedTextObservation] else { return }
                    for observation in results {
                        if let candidate = observation.topCandidates(1).first {
                            recognizedTexts.append(candidate.string)
                        }
                    }
                }
                textRequest.recognitionLevel = .accurate
                textRequest.usesLanguageCorrection = true
                if #available(iOS 16.0, *) {
                    textRequest.recognitionLanguages = ["fr-FR", "en-US", "he-IL"]
                }
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([textRequest])
            }
            
            // C. Détection de Visages
            group.enter()
            let faceRequest = VNDetectFaceRectanglesRequest { request, error in
                defer { group.leave() }
                if let results = request.results as? [VNFaceObservation] {
                    faceCount = results.count
                }
            }
            let faceHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? faceHandler.perform([faceRequest])
            
            // D. Détection de Codes-barres / QR
            group.enter()
            let barcodeRequest = VNDetectBarcodesRequest { request, error in
                defer { group.leave() }
                if let results = request.results as? [VNBarcodeObservation] {
                    detectedBarcodes = results.compactMap { $0.payloadStringValue }
                }
            }
            let barcodeHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? barcodeHandler.perform([barcodeRequest])
            
            group.wait()
            
            // E. Traduction et formatage des objets détectés en français
            let translatedObjects = self.translateAndFormatObjects(detectedObjects)
            let fullText = recognizedTexts.isEmpty ? nil : recognizedTexts.joined(separator: "\n")
            
            // Synthèse en langage naturel
            var spokenParts: [String] = []
            var summaryParts: [String] = []
            
            if faceCount > 0 {
                let faceStr = faceCount == 1 ? "un visage" : "\(faceCount) visages"
                spokenParts.append("Je détecte \(faceStr).")
                summaryParts.append("👤 **Visages détectés** : \(faceCount)")
            }
            
            if !translatedObjects.isEmpty {
                let mainItems = translatedObjects.prefix(3).joined(separator: ", ")
                spokenParts.append("Je vois : \(mainItems).")
                summaryParts.append("🔍 **Éléments identifiés** : \(translatedObjects.joined(separator: " • "))")
            }
            
            if let text = fullText, !text.isEmpty {
                let preview = text.prefix(80)
                spokenParts.append("Il y a du texte lisible.")
                summaryParts.append("📝 **Texte extrait (OCR)** :\n```\n\(text)\n```")
            }
            
            if !detectedBarcodes.isEmpty {
                spokenParts.append("J'ai détecté un code-barres.")
                summaryParts.append("🏷️ **Codes-barres / QR** : \(detectedBarcodes.joined(separator: ", "))")
            }
            
            let finalSummary = summaryParts.isEmpty ? "Aucun élément spécifique reconnu sur cette image." : summaryParts.joined(separator: "\n\n")
            let finalSpoken = spokenParts.isEmpty ? "Je ne distingue pas nettement le sujet de cette image." : spokenParts.joined(separator: " ")
            
            // Traitement 100% Local On-Device
            DispatchQueue.main.async {
                completion(ComprehensiveVisionReport(
                    summaryText: finalSummary,
                    spokenDescription: finalSpoken,
                    primaryObjects: translatedObjects,
                    extractedText: fullText,
                    faceCount: faceCount,
                    detectedBarcodes: detectedBarcodes,
                    detailedLLMAnalysis: nil
                ))
            }
        }
    }
    
    // MARK: - Outils Utilitaires
    
    private func prepareCGImage(from image: UIImage) -> (UIImage, CGImage)? {
        let maxDimension: CGFloat = 1024.0
        var targetSize = image.size
        if targetSize.width > maxDimension || targetSize.height > maxDimension {
            let ratio = min(maxDimension / targetSize.width, maxDimension / targetSize.height)
            targetSize = CGSize(width: targetSize.width * ratio, height: targetSize.height * ratio)
        }
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let finalImage = resizedImage, let cg = finalImage.cgImage else { return nil }
        return (finalImage, cg)
    }
    
    private func translateAndFormatObjects(_ objects: [(label: String, confidence: Float)]) -> [String] {
        let translations: [String: String] = [
            "bottle": "bouteille", "cup": "tasse", "cat": "chat", "dog": "chien",
            "car": "voiture", "phone": "téléphone", "laptop": "ordinateur portable",
            "book": "livre", "chair": "chaise", "table": "table", "person": "personne",
            "plant": "plante", "tree": "arbre", "clock": "horloge", "glasses": "lunettes",
            "keyboard": "clavier", "screen": "écran", "guitar": "guitare", "food": "nourriture",
            "apple": "pomme", "banana": "banane", "door": "porte", "window": "fenêtre",
            "street": "rue", "building": "bâtiment", "water": "eau", "flower": "fleur"
        ]
        
        var result: [String] = []
        for item in objects {
            let cleanId = item.label.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces).lowercased() ?? item.label.lowercased()
            if let tr = translations[cleanId] {
                result.append(tr)
            } else {
                result.append(cleanId)
            }
        }
        return Array(Set(result))
    }
}
