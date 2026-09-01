import Foundation

/// Gestionnaire de Contacts et Résolution d'Intentions d'Appel Vocale
public final class VoiceCallContactManager {
    
    public static let shared = VoiceCallContactManager()
    
    public private(set) var contacts: [VoiceCallContact] = [
        VoiceCallContact(name: "Papa", role: "Famille", phoneNumber: "+33612345678", sipUri: "sip:papa@sarah.webrtc.local", defaultLanguage: "fr", avatarEmoji: "👨"),
        VoiceCallContact(name: "Maman", role: "Famille", phoneNumber: "+33687654321", sipUri: "sip:maman@sarah.webrtc.local", defaultLanguage: "fr", avatarEmoji: "👩"),
        VoiceCallContact(name: "David", role: "Partenaire US", phoneNumber: "+14155552671", sipUri: "sip:david@us.webrtc.local", defaultLanguage: "en", avatarEmoji: "💼"),
        VoiceCallContact(name: "Yohan", role: "Équipe Israël", phoneNumber: "+972541234567", sipUri: "sip:yohan@israel.webrtc.local", defaultLanguage: "he", avatarEmoji: "🇮🇱"),
        VoiceCallContact(name: "Nathan", role: "Expert Médias & WhatsApp", phoneNumber: "+33699887766", sipUri: "sip:nathan@sarah.webrtc.local", defaultLanguage: "en", avatarEmoji: "⚡"),
        VoiceCallContact(name: "Bureau", role: "Travail", phoneNumber: "+33140506070", sipUri: "sip:office@corp.webrtc.local", defaultLanguage: "fr", avatarEmoji: "🏢"),
        VoiceCallContact(name: "Esther", role: "Lead Architecte & Code", phoneNumber: "+33611223344", sipUri: "sip:esther@dev.webrtc.local", defaultLanguage: "fr", avatarEmoji: "💻")
    ]
    
    private init() {}
    
    /// Ajoute ou met à jour un contact
    public func addContact(_ contact: VoiceCallContact) {
        if let idx = contacts.firstIndex(where: { $0.id == contact.id || $0.name.lowercased() == contact.name.lowercased() }) {
            contacts[idx] = contact
        } else {
            contacts.append(contact)
        }
    }
    
    /// Résolution d'intention d'appel à partir d'une commande en langage naturel (ex: "Appelle papa", "Appelle David en anglais")
    public func resolveContact(from query: String) -> (contact: VoiceCallContact, targetLanguage: String?)? {
        let lower = query.lowercased()
            .replacingOccurrences(of: "appelle", with: "")
            .replacingOccurrences(of: "appel", with: "")
            .replacingOccurrences(of: "téléphone à", with: "")
            .replacingOccurrences(of: "telephone a", with: "")
            .replacingOccurrences(of: "passe un appel à", with: "")
            .replacingOccurrences(of: "passe un coup de fil à", with: "")
            .replacingOccurrences(of: "join", with: "")
            .replacingOccurrences(of: "contacte", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Détection de langue explicite demandée
        var detectedLang: String? = nil
        var cleanQuery = lower
        
        if lower.contains("en anglais") || lower.contains("in english") {
            detectedLang = "en"
            cleanQuery = cleanQuery.replacingOccurrences(of: "en anglais", with: "").replacingOccurrences(of: "in english", with: "")
        } else if lower.contains("en hébreu") || lower.contains("en hebreu") || lower.contains("in hebrew") {
            detectedLang = "he"
            cleanQuery = cleanQuery.replacingOccurrences(of: "en hébreu", with: "").replacingOccurrences(of: "en hebreu", with: "").replacingOccurrences(of: "in hebrew", with: "")
        } else if lower.contains("en français") || lower.contains("en francais") || lower.contains("in french") {
            detectedLang = "fr"
            cleanQuery = cleanQuery.replacingOccurrences(of: "en français", with: "").replacingOccurrences(of: "en francais", with: "").replacingOccurrences(of: "in french", with: "")
        }
        
        cleanQuery = cleanQuery.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        
        // 1. Recherche par nom dans les contacts existants
        for c in contacts {
            if cleanQuery.contains(c.name.lowercased()) || c.name.lowercased().contains(cleanQuery) && !cleanQuery.isEmpty {
                return (contact: c, targetLanguage: detectedLang ?? c.defaultLanguage)
            }
        }
        
        // 2. Détection de numéro de téléphone direct (ex: "Appelle le +33612345678")
        let digitsAndPlus = cleanQuery.filter { $0.isNumber || $0 == "+" }
        if digitsAndPlus.count >= 6 {
            let directContact = VoiceCallContact(
                name: digitsAndPlus,
                role: "Numéro direct",
                phoneNumber: digitsAndPlus,
                sipUri: "sip:\(digitsAndPlus)@sarah.webrtc.local",
                defaultLanguage: detectedLang ?? "fr",
                avatarEmoji: "📞"
            )
            return (contact: directContact, targetLanguage: detectedLang ?? "fr")
        }
        
        // 3. Fallback contact ad-hoc si un nom est fourni
        if !cleanQuery.isEmpty && cleanQuery.count > 1 {
            let adHocContact = VoiceCallContact(
                name: cleanQuery.capitalized,
                role: "Correspondant WebRTC",
                phoneNumber: "",
                sipUri: "sip:\(cleanQuery.lowercased())@sarah.webrtc.local",
                defaultLanguage: detectedLang ?? "fr",
                avatarEmoji: "👤"
            )
            return (contact: adHocContact, targetLanguage: detectedLang ?? "fr")
        }
        
        return nil
    }
}
