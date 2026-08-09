import Foundation
import SwiftUI

/// ViewModel principal gérant la logique de conversation avec Sarah IA.
@MainActor
final class ChatViewModel: ObservableObject {
    
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isTyping: Bool = false
    
    private let aiService = AIService.shared
    private let notificationService = NotificationService.shared
    
    init() {
        // Message de bienvenue de Sarah
        let welcome = Message(
            content: "Bonjour ! 👋 Je suis Sarah, votre assistante IA. Posez-moi une question ou dites simplement bonjour ! 😊",
            isFromUser: false
        )
        messages.append(welcome)
    }
    
    /// Envoie le message de l'utilisateur et génère une réponse IA.
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Ajouter le message utilisateur
        let userMessage = Message(content: text, isFromUser: true)
        messages.append(userMessage)
        inputText = ""
        
        // Lancer la génération de réponse IA
        isTyping = true
        
        Task {
            let response = await aiService.generateResponse(for: text)
            
            let aiMessage = Message(content: response, isFromUser: false)
            messages.append(aiMessage)
            isTyping = false
            
            // Envoyer une notification si l'app est en arrière-plan
            await sendNotificationIfNeeded(message: response)
        }
    }
    
    /// Lance un test de réponse différée en arrière-plan.
    /// L'utilisateur a ~5 secondes pour minimiser l'app avant la notification.
    func sendBackgroundTest() {
        let testMessage = Message(
            content: "🔔 Test de notification en arrière-plan lancé ! Minimisez l'app maintenant, vous recevrez une notification dans ~5 secondes.",
            isFromUser: false
        )
        messages.append(testMessage)
        
        isTyping = true
        
        Task {
            let response = await aiService.generateBackgroundTestResponse()
            
            let aiMessage = Message(content: response, isFromUser: false)
            messages.append(aiMessage)
            isTyping = false
            
            // Toujours envoyer la notification pour le test
            notificationService.sendResponseNotification(message: response)
        }
    }
    
    /// Envoie une notification locale si l'application n'est pas au premier plan.
    private func sendNotificationIfNeeded(message: String) async {
        let state = await UIApplication.shared.applicationState
        if state != .active {
            notificationService.sendResponseNotification(message: message)
        }
    }
}
