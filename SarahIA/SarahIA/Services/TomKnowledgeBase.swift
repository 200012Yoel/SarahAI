import Foundation

/// Base de connaissances compressée locale 100% hors-ligne pour Tom (Agent Histoire, Géopolitique & Débats).
/// Couvre les relations internationales, l'histoire politique mondiale depuis 1948, le conflit du Moyen-Orient,
/// la Ve République française, les traités internationaux et les synthèses encyclopédiques.
public final class TomKnowledgeBase {
    
    public static let shared = TomKnowledgeBase()
    
    public struct KnowledgeArticle {
        public let id: String
        public let title: String
        public let keywords: [String]
        public let content: String
        public let summary: String
    }
    
    private var articles: [KnowledgeArticle] = []
    
    private init() {
        populateKnowledge()
    }
    
    private func populateKnowledge() {
        articles = [
            // 1. Histoire & Géopolitique d'Israël et du Moyen-Orient depuis 1948
            KnowledgeArticle(
                id: "israel_1948",
                title: "Création de l'État d'Israël (1948)",
                keywords: ["israel", "1948", "ben gourion", "declaration", "independance", "onu 181", "nakba", "sionisme", "palestine", "mandat britannique"],
                content: """
                Le 14 mai 1948 (5 Iyar 5708), David Ben Gourion proclame l'indépendance de l'État d'Israël à Tel Aviv, concrétisant la résolution 181 de l'ONU du 29 novembre 1947 prévoyant le partage de la Palestine mandataire. Le lendemain, 5 armées arabes (Égypte, Jordanie, Syrie, Liban, Irak) attaquent le nouvel État. La guerre d'indépendance (1948-1949) s'achève par les accords d'armistice de Rhodes, établissant la « Ligne Verte ».
                """,
                summary: "Proclamation le 14 mai 1948 par Ben Gourion après le vote de l'ONU (résolution 181), guerre d'indépendance 1948-1949 et armistice de Rhodes."
            ),
            KnowledgeArticle(
                id: "israel_wars",
                title: "Conflits majeurs au Moyen-Orient (1956, 1967, 1973, 1982)",
                keywords: ["guerre des six jours", "1967", "kippour", "1973", "suez", "1956", "sinai", "golan", "jerusalem", "tsahal", "nasser", "sadate", "dayan"],
                content: """
                - **Crise de Suez (1956)** : Expédition conjointe franco-britannique et israélienne après la nationalisation du canal par Nasser.
                - **Guerre des Six Jours (juin 1967)** : Attaque préventive d'Israël face à la fermeture du détroit de Tiran et aux mouvements de troupes égyptiennes. Victoire fulgurante : réunification de Jérusalem, contrôle de la Cisjordanie, de Gaza, du Sinaï et du plateau du Golan.
                - **Guerre du Kippour (octobre 1973)** : Attaque surprise de l'Égypte et de la Syrie le jour de Yom Kippour. Résistance héroïque et contre-offensive israélienne sous la direction de Golda Meir et Moshe Dayan.
                - **Accords de Camp David (1978-1979)** : Paix historique Israël-Égypte signée par Menahem Begin et Anouar el-Sadate sous l'égide de Jimmy Carter.
                """,
                summary: "Chronologie des guerres de 1956, 1967 (Six Jours), 1973 (Kippour) et paix historique de Camp David (1979)."
            ),
            KnowledgeArticle(
                id: "abraham_accords",
                title: "Accords d'Abraham (2020) & Géopolitique contemporaine",
                keywords: ["accords d abraham", "abraham", "emirats", "bahrein", "maroc", "soudan", "normalisation", "arabie saoudite", "iran", "axe de la resistance"],
                content: """
                Signés à l'automne 2020 sous l'égide des États-Unis, les Accords d'Abraham normalisent les relations diplomatiques, économiques et sécuritaires entre Israël et plusieurs pays arabes : les Émirats arabes unis, Bahreïn, le Maroc et le Soudan. Ils marquent une rupture historique avec l'ancien paradigme, fondant une alliance régionale axée sur l'innovation, le commerce et la dissuasion face à l'Iran et ses proxies (Hezbollah, Houthis, milices).
                """,
                summary: "Normalisation diplomatique historique entre Israël, les Émirats, Bahreïn, le Maroc et le Soudan à partir de 2020."
            ),
            
            // 2. Histoire Politique de France (Ve République & Monde)
            KnowledgeArticle(
                id: "france_ve_republique",
                title: "La Ve République Française (1958 - Présent)",
                keywords: ["de gaulle", "1958", "constitution", "ve republique", "mai 68", "mitterrand", "chirac", "macron", "dissolution", "article 49.3", "cohabitation"],
                content: """
                Fondée par le Général de Gaulle en 1958 lors de la crise d'Algérie, la Constitution du 4 octobre 1958 instaure un régime semi-présidentiel fort avec un exécutif stable. En 1962, le suffrage universel direct pour l'élection présidentielle renforce la légitimité du chef de l'État. 
                Grandes étapes : Présidence de Gaulle (1958-1969), alternance de François Mitterrand en 1981, cohabitations (1986, 1993, 1997), passage au quinquennat en 2000, et recompositions politiques contemporaines.
                """,
                summary: "Régime constitutionnel institué par de Gaulle en 1958, semi-présidentiel, élection au suffrage direct depuis 1962."
            ),
            KnowledgeArticle(
                id: "geopolitique_guerre_froide_actuelle",
                title: "Guerre Froide, Chute de l'URSS et Ordre Multipolaire",
                keywords: ["guerre froide", "otan", "pacte de varsovie", "urss", "chute du mur de berlin", "1989", "chine", "taiwan", "ukraine", "brics", "multipolaire"],
                content: """
                De la bipolarité USA-URSS (1947-1991) à l'ordre multipolaire actuel :
                - Chute du Mur de Berlin (1989) et dissolution de l'URSS (1991).
                - Montée en puissance économique et technologique de la Chine, tensions dans le détroit de Taïwan.
                - Conflits d'Europe de l'Est et recomposition de l'OTAN.
                - Émergence des BRICS+ et compétition stratégique globale (technologies, semi-conducteurs, énergie, IA).
                """,
                summary: "Évolution géopolitique globale depuis 1945 : Guerre Froide, effondrement soviétique, émergence chinoise et monde multipolaire."
            ),
            
            // 3. Débats Philosophiques, Économiques et Grands Enjeux Mondiaux
            KnowledgeArticle(
                id: "ia_technologie_futur",
                title: "Enjeux de l'Intelligence Artificielle & Souveraineté Numérique",
                keywords: ["intelligence artificielle", "llm", "on-device", "souverainete", "transhumanisme", "chips", "nvidia", "apple intelligence", "llama"],
                content: """
                L'IA générative on-device (sur appareil) marque une révolution de confidentialité et d'autonomie face aux clouds centralisés. Les enjeux capitaux résident dans la maîtrise des semi-conducteurs (fonderies TSMC), l'efficience énergétique des modèles locaux (quantification 4-bit, Metal Performance Shaders) et l'alignement éthique sans censure partisane.
                """,
                summary: "Révolution de l'IA locale on-device, indépendance technologique et confidentialité absolue."
            )
        ]
    }
    
    /// Recherche sémantique / par mots-clés dans la base locale de Tom
    public func query(text: String) -> String? {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Recherche par scoring pondéré de mots-clés
        var bestScore = 0
        var bestArticle: KnowledgeArticle? = nil
        
        let words = lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 3 }
        
        for article in articles {
            var score = 0
            for kw in article.keywords {
                if lower.contains(kw) {
                    score += 5
                }
            }
            for w in words {
                if article.title.lowercased().contains(w) {
                    score += 3
                }
                if article.content.lowercased().contains(w) {
                    score += 1
                }
            }
            
            if score > bestScore && score >= 4 {
                bestScore = score
                bestArticle = article
            }
        }
        
        guard let match = bestArticle else { return nil }
        return "🌍 **Tom [Analyse Historique & Géopolitique]**\n\n**\(match.title)**\n\n\(match.content)"
    }
}
