import Foundation

/// Service d'intelligence artificielle simulée.
/// Génère des réponses contextuelles en français après un délai réaliste.
final class AIService {
    
    static let shared = AIService()
    
    private init() {}
    
    /// Génère une réponse IA pour la question donnée.
    /// - Parameter question: La question posée par l'utilisateur.
    /// - Returns: Une réponse textuelle simulée.
    func generateResponse(for question: String) async -> String {
        // Simule un délai de traitement réaliste (2 à 4 secondes)
        let delay = UInt64.random(in: 2_000_000_000...4_000_000_000)
        try? await Task.sleep(nanoseconds: delay)
        
        let lowercased = question.lowercased()
        
        // Réponses contextuelles basées sur des mots-clés
        if lowercased.contains("bonjour") || lowercased.contains("salut") || lowercased.contains("hello") || lowercased.contains("coucou") {
            return pickRandom(from: greetingResponses)
        }
        
        if lowercased.contains("météo") || lowercased.contains("temps") || lowercased.contains("pluie") || lowercased.contains("soleil") {
            return pickRandom(from: weatherResponses)
        }
        
        if lowercased.contains("heure") || lowercased.contains("quelle heure") {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            let time = formatter.string(from: Date())
            return "Il est actuellement \(time). ⏰ Comment puis-je vous aider ?"
        }
        
        if lowercased.contains("aide") || lowercased.contains("aider") || lowercased.contains("help") {
            return pickRandom(from: helpResponses)
        }
        
        if lowercased.contains("merci") || lowercased.contains("super") || lowercased.contains("génial") || lowercased.contains("parfait") {
            return pickRandom(from: thanksResponses)
        }
        
        if lowercased.contains("nom") || lowercased.contains("appelle") || lowercased.contains("qui es") || lowercased.contains("sarah") {
            return pickRandom(from: identityResponses)
        }
        
        if lowercased.contains("blague") || lowercased.contains("rire") || lowercased.contains("drôle") || lowercased.contains("humour") {
            return pickRandom(from: jokeResponses)
        }
        
        if lowercased.contains("recette") || lowercased.contains("cuisine") || lowercased.contains("manger") || lowercased.contains("repas") {
            return pickRandom(from: cookingResponses)
        }
        
        if lowercased.contains("musique") || lowercased.contains("chanson") || lowercased.contains("écouter") {
            return pickRandom(from: musicResponses)
        }
        
        if lowercased.contains("au revoir") || lowercased.contains("bye") || lowercased.contains("à bientôt") || lowercased.contains("bonne nuit") {
            return pickRandom(from: goodbyeResponses)
        }
        
        // Réponse par défaut
        return pickRandom(from: defaultResponses)
    }
    
    /// Génère une réponse rapide pour le test de notification en arrière-plan.
    func generateBackgroundTestResponse() async -> String {
        // Délai plus long pour permettre à l'utilisateur de mettre l'app en arrière-plan
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        return "🔔 Ceci est un test de notification en arrière-plan ! Sarah IA fonctionne même quand l'application n'est pas visible. 🚀"
    }
    
    // MARK: - Pools de réponses
    
    private let greetingResponses = [
        "Bonjour ! 👋 Je suis Sarah, votre assistante IA. Comment puis-je vous aider aujourd'hui ?",
        "Salut ! Ravie de vous retrouver. 😊 Que puis-je faire pour vous ?",
        "Hey ! Bienvenue ! Je suis prête à répondre à vos questions. 💬",
        "Bonjour ! ☀️ Belle journée pour discuter. Qu'avez-vous en tête ?"
    ]
    
    private let weatherResponses = [
        "Je ne peux pas accéder à la météo en temps réel pour le moment, mais je vous recommande de vérifier votre application météo préférée ! 🌤️ En attendant, je peux vous aider avec autre chose.",
        "La météo est capricieuse, n'est-ce pas ? ☁️ Malheureusement, je n'ai pas accès aux données météo en direct. Avez-vous une autre question ?",
        "Pour la météo, je vous conseille de consulter Météo-France ou votre app météo favorite ! 🌡️ Je suis meilleure pour les conversations. 😄"
    ]
    
    private let helpResponses = [
        "Bien sûr, je suis là pour vous ! 🤝 Vous pouvez me poser n'importe quelle question, me demander une blague, ou simplement discuter. Que souhaitez-vous ?",
        "Je peux vous aider de plusieurs façons :\n• 💬 Discuter et répondre à vos questions\n• 😄 Raconter des blagues\n• 🔔 Tester les notifications en arrière-plan\n\nQue voulez-vous essayer ?",
        "Je suis Sarah, votre assistante IA ! Je suis ici pour discuter avec vous, répondre à vos questions, et vous accompagner. N'hésitez pas à me poser vos questions ! 💡"
    ]
    
    private let thanksResponses = [
        "De rien ! C'est un plaisir de vous aider. 😊 N'hésitez pas si vous avez d'autres questions !",
        "Avec plaisir ! 🌟 Je suis toujours là si vous avez besoin de moi.",
        "Merci à vous ! C'est motivant de savoir que je peux aider. 💪 Autre chose ?",
        "Pas de quoi ! 😄 C'est exactement pour ça que je suis là."
    ]
    
    private let identityResponses = [
        "Je suis Sarah IA, votre assistante intelligente ! 🤖 J'ai été conçue pour discuter avec vous et répondre à vos questions en français.",
        "Mon nom est Sarah ! Je suis une intelligence artificielle embarquée sur votre iPhone. 📱 Comment puis-je vous être utile ?",
        "Je m'appelle Sarah IA — votre compagne de conversation ! 💬 Je suis là pour vous aider et discuter avec vous."
    ]
    
    private let jokeResponses = [
        "Pourquoi les plongeurs plongent-ils toujours en arrière et jamais en avant ? 🤔 Parce que sinon ils tomberaient dans le bateau ! 😂",
        "Qu'est-ce qu'un canif ? 🔪 Un petit fien ! 😄",
        "Pourquoi est-ce que le chat traverse-t-il la route ? 🐱 Pour aller de l'autre côté... du chat-min ! 😸",
        "Deux informaticiens discutent : \"C'est quoi ton adresse IP ?\" — \"192.168... attends, c'est personnel !\" 💻😄",
        "Comment appelle-t-on un chat tombé dans un pot de peinture le jour de Noël ? 🎄 Un chat-peint de Noël ! 🐱🎨"
    ]
    
    private let cookingResponses = [
        "J'adore parler cuisine ! 🍳 Voici une idée simple : des pâtes aglio e olio — faites revenir de l'ail dans de l'huile d'olive, ajoutez du piment, et mélangez avec des spaghetti. Rapide, délicieux, et élégant !",
        "Pour un repas rapide, je suggère un croque-monsieur revisité : pain de mie, jambon, fromage gruyère, et une béchamel maison. Passez-le au four 10 minutes et régalez-vous ! 🧀",
        "Que diriez-vous d'une salade composée ? 🥗 Mélangez de la roquette, des tomates cerises, de la mozzarella, et arrosez d'un filet de vinaigre balsamique. Simple et délicieux !"
    ]
    
    private let musicResponses = [
        "La musique, quel beau sujet ! 🎵 Je ne peux pas jouer de la musique, mais je vous recommande d'écouter quelques classiques français : Édith Piaf, Charles Aznavour, ou pour du moderne, Stromae !",
        "J'adore la musique ! 🎶 Si vous cherchez de l'inspiration, explorez les playlists de Daft Punk, Air, ou Christine and the Queens. La musique française a tellement à offrir !",
        "La musique adoucit les mœurs ! 🎧 Dites-moi quel genre vous aimez et je pourrai vous suggérer des artistes."
    ]
    
    private let goodbyeResponses = [
        "Au revoir ! 👋 C'était un plaisir de discuter avec vous. À bientôt !",
        "À la prochaine ! 🌟 N'hésitez pas à revenir quand vous voulez. Bonne journée !",
        "Bye bye ! 😊 Prenez soin de vous et à très vite !",
        "Bonne nuit ! 🌙 Dormez bien et à demain peut-être !"
    ]
    
    private let defaultResponses = [
        "C'est une question intéressante ! 🤔 En tant qu'IA simulée, je n'ai pas toutes les réponses, mais je fais de mon mieux pour vous aider. Pourriez-vous reformuler votre question ?",
        "Hmm, je réfléchis... 💭 Je ne suis pas sûre d'avoir la réponse parfaite, mais je suis toujours en apprentissage ! Essayez de me poser la question autrement.",
        "Bonne question ! 💡 Je suis une IA en développement, alors certaines réponses me dépassent encore. Mais n'hésitez pas à continuer de me challenger !",
        "Intéressant ! 🧠 Je note votre question. Même si je ne peux pas y répondre maintenant, je m'améliore constamment. Essayez autre chose en attendant !",
        "Je comprends votre question, mais ma base de connaissances est encore limitée. 📚 Essayons un autre sujet ! Vous pouvez me demander des blagues, de l'aide, ou simplement discuter."
    ]
    
    // MARK: - Helpers
    
    private func pickRandom(from pool: [String]) -> String {
        pool.randomElement() ?? "Je suis là pour vous aider ! 😊"
    }
}
