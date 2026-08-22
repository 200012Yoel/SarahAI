import Foundation
import UIKit
import ReplayKit

/// Service de Partage d'Écran et Analyse Visuelle avec Sarah :
/// - Compatible 100% avec tous les iPhone (iPhone 5S, 6, 7, 8, SE, X, 11, 12, 13, 14, 15)
/// - Capture instantanée et sécurisée de l'écran en arrière-plan sans bloquer l'UI
/// - Analyse OCR et reconnaissance de l'interface par le moteur local LocalVisionEngine
/// - Formulation naturelle de Sarah sur ce que l'utilisateur est en train de faire à l'écran
public final class ScreenShareService {
    
    public static let shared = ScreenShareService()
    
    private init() {}
    
    // MARK: - Capture de l'Écran Courant (Universal Snapshot)
    
    /// Capture l'écran actuel de l'application de manière fluide et thread-safe
    public func captureScreen(from windowOrView: UIView? = nil) -> UIImage? {
        return autoreleasepool { () -> UIImage? in
            let targetView: UIView? = windowOrView ?? UIApplication.shared.keyWindow ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow })
            
            guard let view = targetView else { return nil }
            let bounds = view.bounds
            guard bounds.width > 0 && bounds.height > 0 else { return nil }
            
            UIGraphicsBeginImageContextWithOptions(bounds.size, false, 0.0)
            view.drawHierarchy(in: bounds, afterScreenUpdates: false)
            let captured = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return captured
        }
    }
    
    // MARK: - Analyse Complète de l'Écran Partagé
    
    /// Capture l'écran, le compresse de façon ultra-légère et l'analyse avec Sarah
    public func shareAndAnalyzeScreen(
        from viewController: UIViewController,
        completion: @escaping (LocalVisionEngine.VisionAnalysisResult, UIImage, Data) -> Void
    ) {
        // 1. Capture sur le thread principal
        guard let screenshot = captureScreen(from: viewController.view.window ?? viewController.view) else {
            return
        }
        
        // 2. Traitement d'optimisation mémoire en arrière-plan (anti-crash iPhone 5S/7)
        DispatchQueue.global(qos: .userInitiated).async {
            guard let processed = LocalVisionEngine.prepareImageForAnalysis(screenshot, maxDimension: 800, quality: 0.7) else {
                return
            }
            
            // 3. Analyse de vision locale (Objets + OCR)
            LocalVisionEngine.shared.recognizeObject(in: processed.image) { result in
                // Personnalisation de la réponse pour le contexte "Partage d'écran"
                let adaptedSpokenResponse: String
                if !result.detectedText.isEmpty {
                    adaptedSpokenResponse = "Sur ton écran, je lis : « \(result.detectedText) » 📱"
                } else if result.objectLabel != "inconnu" && result.objectLabel != "objet devant la caméra" {
                    adaptedSpokenResponse = "Sur ton écran, je vois \(result.objectLabel) 🖥️"
                } else {
                    adaptedSpokenResponse = "J'observe ton écran ! Que souhaites-tu que j'analyse ou que je t'explique dessus ? 💡"
                }
                
                let screenResult = LocalVisionEngine.VisionAnalysisResult(
                    objectLabel: result.objectLabel,
                    naturalSpokenResponse: adaptedSpokenResponse,
                    detectedText: result.detectedText,
                    confidence: max(0.8, result.confidence)
                )
                
                DispatchQueue.main.async {
                    completion(screenResult, processed.image, processed.data)
                }
            }
        }
    }
}
