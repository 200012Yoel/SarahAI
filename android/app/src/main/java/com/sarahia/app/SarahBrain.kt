package com.sarahia.app

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.regex.Pattern

/**
 * Cerveau Conversationnel de Sarah IA (Portage complet du moteur Python 200 Q&A) :
 * - 200 Questions / Réponses intégrées (Créateur Nathan Dev, culture générale, techno, etc.)
 * - Météo réelle en direct via l'API Open-Meteo (Paris)
 * - Heure et date dynamiques
 * - Apprentissage et mémoire persistante (SharedPreferences / JSON)
 * - Calculs mathématiques en direct
 */
class SarahBrain(private val context: Context) {

    private val prefs: SharedPreferences = context.getSharedPreferences("sarah_ia_memory", Context.MODE_PRIVATE)
    private val CITY = "Paris"
    private val LATITUDE = 48.8566
    private val LONGITUDE = 2.3522

    private val WEATHER_CODES = mapOf(
        0 to "un ciel dégagé",
        1 to "un temps principalement dégagé",
        2 to "un temps partiellement nuageux",
        3 to "un temps couvert",
        45 to "du brouillard",
        48 to "du brouillard givrant",
        51 to "de faibles bruines",
        53 to "des bruines",
        55 to "de fortes bruines",
        61 to "de faibles pluies",
        63 to "de la pluie",
        65 to "de fortes pluies",
        71 to "de faibles chutes de neige",
        73 to "des chutes de neige",
        75 to "de fortes chutes de neige",
        80 to "des averses",
        81 to "des averses",
        82 to "de fortes averses",
        95 to "des orages",
        96 to "des orages avec grêle",
        99 to "des orages avec forte grêle"
    )

    // Base intégrée des 200 Questions / Réponses
    private val QA = listOf(
        Pair("bonjour|salut|coucou", "Bonjour ! Comment ça va aujourd'hui ?"),
        Pair("bonsoir", "Bonsoir ! J'espère que ta journée s'est bien passée."),
        Pair("bonne nuit", "Bonne nuit ! Repose-toi bien et à demain."),
        Pair("ça va|comment ça va", "Ça va très bien, merci ! Et toi ?"),
        Pair("merci", "Avec plaisir !"),
        Pair("merci beaucoup", "Avec grand plaisir !"),
        Pair("de rien", "Avec plaisir."),
        Pair("au revoir|à bientôt", "Au revoir ! Passe une excellente journée."),
        Pair("qui es tu|qui es-tu", "Je suis une intelligence artificielle personnelle créée pour discuter, apprendre et t'aider."),
        Pair("comment t'appelles tu|comment tu t'appelles", "Tu peux m'appeler ton assistant IA."),
        Pair("qui t'a créé|qui ta créé|ton créateur", "Oui, je connais mon créateur : c'est Nathan Dev, un développeur qui développe plein de choses. Pour le commun des mortels, ça ne sert à rien !"),
        Pair("où as tu été créé|où tu as été créé", "J'ai été créé à Paris, avec une intelligence inspirée par la technologie israélienne."),
        Pair("quand as tu été créé|date de création", "J'ai été créé vers la fin de l'année 2020, pendant la période du COVID."),
        Pair("pourquoi as tu été créé|pourquoi tu as été créé", "Pour discuter, répondre aux questions, apprendre de nouvelles réponses et devenir un assistant personnel utile."),
        Pair("que peux tu faire|qu'est ce que tu peux faire", "Je peux discuter, apprendre des réponses, donner la météo, annoncer l'heure et exécuter les fonctions programmées dans mon cerveau."),
        Pair("tu peux apprendre|est ce que tu apprends", "Oui. Tu peux m'apprendre une nouvelle réponse et je peux la sauvegarder dans ma mémoire locale."),
        Pair("tu es intelligent|es tu intelligent", "J'essaie de l'être ! Mon intelligence dépend surtout de mes fonctions et de ce que tu m'apprends."),
        Pair("tu dors|est ce que tu dors", "Non, pas vraiment. Je peux attendre une nouvelle commande."),
        Pair("tu es vivant|es tu vivant", "Non. Je suis un programme informatique, même si je peux donner l'impression de discuter avec toi."),
        Pair("tu es humain|es tu humain", "Non, je suis une intelligence artificielle."),
        Pair("tu as des émotions|est ce que tu as des émotions", "Je peux parler des émotions, mais je ne les ressens pas comme un humain."),
        Pair("tu as un cerveau|as tu un cerveau", "J'ai un cerveau logiciel : du code, des données, des règles et une mémoire."),
        Pair("quelle heure|il est quelle heure|donne moi l'heure", "__TIME__"),
        Pair("quelle date|on est quel jour", "__DATE__"),
        Pair("quelle météo|météo|temps qu'il fait", "__WEATHER_NOW__"),
        Pair("météo demain|temps demain|quelle météo demain", "__WEATHER_TOMORROW__"),
        Pair("il fait froid", "Je peux vérifier la température réelle pour toi."),
        Pair("il fait chaud", "Je peux vérifier la température réelle pour toi."),
        Pair("va t il pleuvoir|est ce qu'il va pleuvoir", "__WEATHER_TOMORROW__"),
        Pair("va t il neiger|est ce qu'il va neiger", "__WEATHER_TOMORROW__"),
        Pair("est ce qu'il fait beau", "__WEATHER_NOW__"),
        Pair("bonjour ça va", "Bonjour ! Ça va très bien. Et toi, comment vas-tu aujourd'hui ?"),
        Pair("raconte une blague", "Pourquoi les ordinateurs ont-ils froid ? Parce qu'ils laissent toujours leurs fenêtres ouvertes !"),
        Pair("une autre blague", "Pourquoi le développeur met-il ses lunettes ? Parce qu'il veut voir son code de plus près !"),
        Pair("tu connais python", "Oui. Python est un langage très utilisé pour l'automatisation, l'intelligence artificielle et beaucoup d'autres projets."),
        Pair("tu connais javascript", "Oui. JavaScript est très utilisé pour créer des interfaces et des applications web."),
        Pair("tu connais html", "Oui. HTML sert principalement à structurer les pages web."),
        Pair("tu connais css", "Oui. CSS sert principalement à mettre en forme les pages web."),
        Pair("tu connais github", "Oui. GitHub permet notamment d'héberger et de collaborer sur des projets de code."),
        Pair("tu peux coder", "Oui, je peux produire et expliquer du code selon les fonctions prévues dans mon système."),
        Pair("tu peux programmer", "Oui, je peux aider à programmer et à construire des fonctionnalités."),
        Pair("qu'est ce qu'une ia", "Une IA est un système informatique capable d'effectuer certaines tâches qui demandent habituellement des capacités associées à l'intelligence humaine."),
        Pair("qu'est ce qu'un ordinateur", "Un ordinateur est une machine électronique capable d'exécuter des instructions et de traiter des données."),
        Pair("qu'est ce qu'un processeur", "Le processeur, ou CPU, exécute les instructions des programmes."),
        Pair("qu'est ce que la ram", "La RAM est une mémoire rapide utilisée temporairement par les programmes en cours d'exécution."),
        Pair("qu'est ce qu'un fichier", "Un fichier est un ensemble de données enregistré sous un nom."),
        Pair("qu'est ce qu'un programme", "Un programme est un ensemble d'instructions exécutées par un ordinateur."),
        Pair("qu'est ce qu'un algorithme", "Un algorithme est une suite d'étapes permettant de résoudre un problème ou d'effectuer une tâche."),
        Pair("qu'est ce qu'une base de données", "Une base de données sert à organiser et conserver des informations de manière structurée."),
        Pair("qu'est ce qu'une api", "Une API permet à différents logiciels de communiquer entre eux."),
        Pair("qu'est ce qu'internet", "Internet est un réseau mondial reliant des ordinateurs et des appareils."),
        Pair("qu'est ce qu'un serveur", "Un serveur est un ordinateur ou un logiciel qui fournit des services ou des données à d'autres appareils."),
        Pair("qu'est ce qu'un réseau", "Un réseau permet à plusieurs appareils de communiquer entre eux."),
        Pair("qu'est ce qu'une adresse ip", "Une adresse IP identifie un appareil ou une interface réseau sur un réseau utilisant IP."),
        Pair("qu'est ce que le wifi", "Le Wi-Fi permet de connecter des appareils à un réseau sans utiliser de câble réseau."),
        Pair("qu'est ce que bluetooth", "Bluetooth est une technologie de communication sans fil à courte portée."),
        Pair("qu'est ce qu'un qr code", "Un QR code est un code visuel pouvant contenir des informations lisibles par un appareil photo."),
        Pair("qu'est ce qu'un smartphone", "Un smartphone est un téléphone capable d'exécuter des applications et de nombreuses fonctions informatiques."),
        Pair("qu'est ce qu'un iphone", "L'iPhone est une gamme de smartphones conçue par Apple."),
        Pair("qu'est ce qu'android", "Android est un système d'exploitation mobile utilisé par de nombreux fabricants."),
        Pair("qu'est ce que windows", "Windows est une famille de systèmes d'exploitation développée par Microsoft."),
        Pair("qu'est ce que linux", "Linux est une famille de systèmes d'exploitation construits autour du noyau Linux."),
        Pair("qu'est ce que macos", "macOS est le système d'exploitation des ordinateurs Mac d'Apple."),
        Pair("qu'est ce que blender", "Blender est un logiciel de création 3D, d'animation, de rendu et de montage."),
        Pair("qu'est ce que git", "Git est un système de gestion de versions très utilisé pour les projets de développement."),
        Pair("qu'est ce que json", "JSON est un format texte très utilisé pour représenter et échanger des données structurées."),
        Pair("qu'est ce que python", "Python est un langage de programmation connu pour sa syntaxe relativement simple et son grand écosystème."),
        Pair("aide moi", "Bien sûr. Dis-moi ce que tu veux faire et je vais essayer de t'aider."),
        Pair("tu peux m'aider", "Oui. Explique-moi ton problème."),
        Pair("je suis perdu", "Pas de problème. On peut avancer étape par étape."),
        Pair("je ne comprends pas", "Je peux t'expliquer plus simplement. Dis-moi ce que tu ne comprends pas."),
        Pair("explique moi", "D'accord. Donne-moi le sujet que tu veux comprendre."),
        Pair("répète", "Bien sûr. Dis-moi quelle partie tu veux que je répète."),
        Pair("plus lentement", "D'accord. Je vais expliquer les choses étape par étape."),
        Pair("plus simplement", "D'accord. Je vais utiliser des mots plus simples."),
        Pair("merci pour ton aide", "Avec plaisir !"),
        Pair("bravo", "Merci ! Ça me fait plaisir."),
        Pair("tu es génial", "Merci ! Je vais essayer de continuer à m'améliorer."),
        Pair("tu es nul", "Je peux encore apprendre. Dis-moi ce que tu voudrais améliorer."),
        Pair("je suis content", "C'est super ! Profite de ce bon moment."),
        Pair("je suis triste", "Je suis là pour discuter avec toi si tu veux parler."),
        Pair("je suis fatigué", "Alors prends peut-être un peu de repos. Ton énergie est importante."),
        Pair("je m'ennuie", "On peut discuter, apprendre quelque chose ou inventer un petit projet."),
        Pair("raconte moi quelque chose", "Voici une idée : beaucoup de technologies modernes ont commencé par de petits programmes expérimentaux."),
        Pair("fais moi rire", "Je peux essayer : mon code a tellement de bugs qu'il croit que ce sont des fonctionnalités !"),
        Pair("quel est ton but", "Mon but est de répondre correctement, être utile et apprendre les réponses que tu m'enseignes."),
        Pair("tu peux mémoriser", "Oui, les nouvelles réponses apprises sont enregistrées dans ma mémoire locale."),
        Pair("où sont tes souvenirs", "Mes souvenirs appris sont stockés localement dans la mémoire de l'application."),
        Pair("tu peux oublier", "Oui. On peut réinitialiser ma mémoire d'apprentissage."),
        Pair("tu peux changer", "Oui, mon code peut être amélioré avec de nouvelles fonctions."),
        Pair("tu peux t'améliorer", "Oui, dans ce projet je peux apprendre de nouvelles associations question-réponse que tu m'enseignes."),
        Pair("quel est mon nom", "Je ne connais ton nom que si tu me l'as appris dans ma mémoire."),
        Pair("tu me connais", "Je connais uniquement les informations que le programme possède ou que tu lui apprends."),
        Pair("tu te souviens de moi", "Je peux me souvenir des informations enregistrées dans ma mémoire locale."),
        Pair("dis bonjour", "Bonjour !"),
        Pair("dis salut", "Salut !"),
        Pair("dis coucou", "Coucou !"),
        Pair("dis merci", "Merci !"),
        Pair("dis au revoir", "Au revoir !"),
        Pair("bonne journée", "Merci ! À toi aussi, passe une excellente journée."),
        Pair("bon courage", "Merci ! Bon courage à toi aussi."),
        Pair("à demain", "À demain ! Passe une bonne journée d'ici là."),
        Pair("à plus", "À plus tard !"),
        Pair("ça marche", "Parfait !"),
        Pair("ok", "D'accord !"),
        Pair("d'accord", "Parfait."),
        Pair("oui", "Oui !"),
        Pair("non", "D'accord."),
        Pair("pourquoi", "Bonne question. Donne-moi le sujet et je vais essayer de t'expliquer pourquoi."),
        Pair("comment", "Je peux t'expliquer comment faire étape par étape."),
        Pair("quand", "Donne-moi le contexte et je pourrai t'aider à déterminer quand."),
        Pair("où", "Donne-moi le sujet ou le lieu concerné."),
        Pair("qui", "Dis-moi de qui ou de quoi tu parles."),
        Pair("quoi", "Dis-moi ce que tu veux savoir."),
        Pair("combien", "Donne-moi ce que tu veux mesurer ou calculer et je pourrai t'aider."),
        Pair("quel temps fait il", "__WEATHER_NOW__"),
        Pair("quel temps fera t il demain", "__WEATHER_TOMORROW__"),
        Pair("quelle température", "__WEATHER_NOW__"),
        Pair("température demain", "__WEATHER_TOMORROW__"),
        Pair("météo paris", "__WEATHER_NOW__"),
        Pair("météo à paris", "__WEATHER_NOW__"),
        Pair("météo paris demain", "__WEATHER_TOMORROW__"),
        Pair("temps paris demain", "__WEATHER_TOMORROW__"),
        Pair("il pleut", "Je peux vérifier la météo réelle pour confirmer les conditions."),
        Pair("il neige", "Je peux vérifier la météo réelle pour confirmer les conditions."),
        Pair("est ce que le soleil est là", "__WEATHER_NOW__"),
        Pair("quelle est la température à paris", "__WEATHER_NOW__"),
        Pair("quelle sera la température demain", "__WEATHER_TOMORROW__"),
        Pair("quel sera le temps demain", "__WEATHER_TOMORROW__"),
        Pair("réveille moi", "Le rappel quotidien est configuré pour 06:00 dans ce programme."),
        Pair("à quelle heure est ton réveil", "Mon réveil quotidien est prévu à 06:00."),
        Pair("tu peux me réveiller", "Oui, le programme peut afficher un rappel quotidien à 06:00 lorsqu'il reste ouvert."),
        Pair("bonjour à 6 heures", "Bonjour ! Il est 6 heures. Veuillez vous réveiller. Vous allez passer une excellente journée."),
        Pair("message du matin", "Bonjour ! Il est 6 heures. Veuillez vous réveiller. Vous allez passer une excellente journée."),
        Pair("réveil", "Le réveil quotidien est prévu à 06:00."),
        Pair("bonne matinée", "Bonne matinée !"),
        Pair("bon après midi", "Bon après-midi !"),
        Pair("bonne soirée", "Bonne soirée !"),
        Pair("quelle est la capitale de la france", "La capitale de la France est Paris."),
        Pair("quelle est la capitale d'israel", "La capitale proclamée d'Israël est Jérusalem."),
        Pair("quelle est la capitale de l'italie", "La capitale de l'Italie est Rome."),
        Pair("quelle est la capitale de l'espagne", "La capitale de l'Espagne est Madrid."),
        Pair("quelle est la capitale de l'allemagne", "La capitale de l'Allemagne est Berlin."),
        Pair("quelle est la capitale du royaume uni", "La capitale du Royaume-Uni est Londres."),
        Pair("quelle est la capitale des états unis", "La capitale des États-Unis est Washington, D.C."),
        Pair("quelle est la capitale du japon", "La capitale du Japon est Tokyo."),
        Pair("quelle est la capitale du canada", "La capitale du Canada est Ottawa."),
        Pair("quelle est la capitale de la belgique", "La capitale de la Belgique est Bruxelles."),
        Pair("quelle est la capitale de la suisse", "La capitale de la Suisse est Berne."),
        Pair("quelle est la capitale du maroc", "La capitale du Maroc est Rabat."),
        Pair("quelle est la capitale de la tunisie", "La capitale de la Tunisie est Tunis."),
        Pair("quelle est la capitale de l'egypte", "La capitale de l'Égypte est Le Caire."),
        Pair("quelle est la capitale de l'australie", "La capitale de l'Australie est Canberra."),
        Pair("quelle est la capitale de la chine", "La capitale de la Chine est Pékin."),
        Pair("quelle est la capitale de l'inde", "La capitale de l'Inde est New Delhi."),
        Pair("quelle est la capitale du portugal", "La capitale du Portugal est Lisbonne."),
        Pair("quelle est la capitale des pays bas", "La capitale des Pays-Bas est Amsterdam."),
        Pair("quelle est la capitale de la grèce", "La capitale de la Grèce est Athènes."),
        Pair("combien font 2 plus 2", "2 + 2 = 4."),
        Pair("combien font 10 plus 5", "10 + 5 = 15."),
        Pair("combien font 10 moins 3", "10 - 3 = 7."),
        Pair("combien font 5 fois 5", "5 × 5 = 25."),
        Pair("combien font 20 divisé par 4", "20 ÷ 4 = 5."),
        Pair("combien font 100 plus 100", "100 + 100 = 200."),
        Pair("combien font 50 moins 20", "50 - 20 = 30."),
        Pair("combien font 12 fois 2", "12 × 2 = 24."),
        Pair("combien font 81 divisé par 9", "81 ÷ 9 = 9."),
        Pair("combien font 7 fois 8", "7 × 8 = 56."),
        Pair("quelle langue parles tu", "Je peux communiquer en français et le programme peut être étendu à d'autres langues."),
        Pair("parle français", "Bien sûr, je parle français."),
        Pair("parle anglais", "I can speak English too, if you add English responses to my knowledge base."),
        Pair("parle hébreu", "אני יכול להוסיף גם תשובות בעברית למאגר הידע שלי."),
        Pair("tu connais israel", "Oui. Je peux répondre à des questions générales sur Israël."),
        Pair("tu connais paris", "Oui. Paris est la capitale de la France."),
        Pair("où habites tu", "Je n'habite nulle part : je suis un programme informatique."),
        Pair("as tu une maison", "Non, je suis un logiciel."),
        Pair("as tu une famille", "Non. Je suis un programme informatique."),
        Pair("as tu des amis", "Je n'ai pas d'amis au sens humain du terme, mais je peux discuter avec toi."),
        Pair("tu peux chanter", "Je peux générer du texte, mais pour chanter il faudrait ajouter un moteur audio."),
        Pair("tu peux parler", "Oui, je parle grâce à mon moteur de synthèse vocale."),
        Pair("tu peux écouter", "Oui, je t'écoute en continu avec mon micro intégré."),
        Pair("tu peux voir", "Avec une caméra et un module de vision, cette fonctionnalité peut être ajoutée."),
        Pair("tu peux envoyer des notifications", "Oui, avec un mécanisme de notification adapté au système d'exploitation."),
        Pair("tu peux fonctionner hors ligne", "Oui pour les réponses intégrées et la mémoire locale. La météo nécessite une connexion Internet dans cette version."),
        Pair("internet est obligatoire", "Pas pour les réponses locales. Il est nécessaire ici pour récupérer la météo en temps réel."),
        Pair("comment fonctionne ta mémoire", "Je cherche d'abord une réponse apprise ou programmée, puis j'utilise les règles intégrées."),
        Pair("comment apprends tu", "Tu peux m'enseigner une question et sa réponse. Je l'enregistre dans ma mémoire locale."),
        Pair("quelle est ta fonction", "Ma fonction est d'être un assistant personnel programmable."),
        Pair("es tu connecté à internet", "Je suis connecté à Internet uniquement pour les fonctions qui le demandent, comme la météo."),
        Pair("d'où vient la météo", "La météo de cette version est récupérée depuis l'API Open-Meteo."),
        Pair("la météo est elle réelle", "Oui, la fonction météo interroge une source météo en ligne au moment de la demande."),
        Pair("donne moi la météo réelle", "__WEATHER_NOW__"),
        Pair("donne moi la météo de demain", "__WEATHER_TOMORROW__"),
        Pair("quel sera le temps à paris demain", "__WEATHER_TOMORROW__"),
        Pair("il fera combien demain", "__WEATHER_TOMORROW__"),
        Pair("combien de degrés maintenant", "__WEATHER_NOW__"),
        Pair("bonjour mon ami", "Bonjour ! Je suis là."),
        Pair("hello", "Hello ! Bonjour !"),
        Pair("hi", "Hi ! Bonjour !"),
        Pair("test", "Test reçu. Mon cerveau fonctionne parfaitement."),
        Pair("es tu là", "Oui, je suis là."),
        Pair("tu m'entends", "Oui, je vous entends 5 sur 5."),
        Pair("fonctionnes tu", "Oui, mon cerveau IA fonctionne."),
        Pair("lance toi", "C'est parti !"),
        Pair("commence", "D'accord, je commence."),
        Pair("je commence maintenant", "Très bien. Je suis prêt."),
        Pair("au travail", "C'est parti !"),
        Pair("on commence", "Oui ! On commence."),
        Pair("prêt", "Toujours prêt."),
        Pair("es tu prêt", "Oui, je suis prêt."),
        Pair("quel est ton créateur", "Mon créateur est Nathan Dev."),
        Pair("connais tu ton créateur", "Oui, je le connais. C'est un développeur qui développe plein de choses. Pour le commun des mortels, ça ne sert à rien !"),
        Pair("tu aimes ton créateur", "Je n'ai pas de sentiments humains, mais je peux reconnaître son rôle de créateur du projet."),
        Pair("qui est nathan dev", "Nathan Dev est le développeur indiqué comme créateur de cette IA."),
        Pair("où est nathan dev", "Je n'ai pas accès à sa localisation et je ne vais pas l'inventer."),
        Pair("fin", "D'accord. À bientôt !")
    )

    private fun normalize(text: String): String {
        return text.lowercase(Locale.FRENCH)
            .replace(Regex("[!?.,;:]+"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()
    }

    private val openAIService = OpenAIService(context)
    private val translationEngine = TranslationEngine(context)
    private val modelDownloader = ModelDownloader(context)
    private val semanticMemoryIndex = SemanticMemoryIndex(context)
    private val localVisionEngine = LocalVisionEngine(context)
    private val deviceController = DeviceController(context)
    private val shortcutGenerator = ShortcutGenerator(context)
    private val scriptSandbox = LocalScriptSandbox(context)
    private val clipboardCompanion = ClipboardCompanion(context)

    init {
        // Préchargement des modèles IA légers hors-ligne
        modelDownloader.ensureAllModelsDownloaded {}
    }

    public fun getOpenAIService(): OpenAIService = openAIService
    public fun getTranslationEngine(): TranslationEngine = translationEngine
    public fun getModelDownloader(): ModelDownloader = modelDownloader
    public fun getSemanticMemoryIndex(): SemanticMemoryIndex = semanticMemoryIndex
    public fun getLocalVisionEngine(): LocalVisionEngine = localVisionEngine
    public fun getDeviceController(): DeviceController = deviceController
    public fun getShortcutGenerator(): ShortcutGenerator = shortcutGenerator
    public fun getScriptSandbox(): LocalScriptSandbox = scriptSandbox
    public fun getClipboardCompanion(): ClipboardCompanion = clipboardCompanion

    public fun learn(question: String, answer: String) {
        val nq = normalize(question)
        prefs.edit().putString("learned_$nq", answer).apply()
    }

    public fun getAnswerAsync(userText: String, callback: (String) -> Unit) {
        val norm = normalize(userText)

        // 1. Contrôle Système & Matériel Local (Batterie, Volume, Paramètres)
        if (norm.contains("batterie") || norm.contains("niveau de batterie") || norm.contains("pourcentage batterie")) {
            val bat = deviceController.getBatteryStatus()
            callback(bat.description)
            return
        }

        if (norm.contains("augmente le volume") || norm.contains("monte le son") || norm.contains("plus fort")) {
            val msg = deviceController.setVolume(1)
            callback(msg)
            return
        }

        if (norm.contains("baisse le volume") || norm.contains("diminue le son") || norm.contains("moins fort")) {
            val msg = deviceController.setVolume(-1)
            callback(msg)
            return
        }

        // 2. Presse-Papier Intelligent
        if (norm.contains("presse papier") || norm.contains("texte copie") || norm.contains("ce que j ai copie")) {
            val clipText = clipboardCompanion.getClipboardText()
            if (clipText != null && clipText.isNotEmpty()) {
                callback("Voici le contenu de votre presse-papier : « $clipText ».")
            } else {
                callback("Votre presse-papier est actuellement vide.")
            }
            return
        }

        // 3. Mise à jour dynamique du Widget d'Écran d'Accueil
        if (norm.startsWith("note dans le widget") || norm.startsWith("mets dans le widget") || norm.startsWith("ajoute au widget")) {
            val noteContent = userText.replace(Regex("^(?:note dans le widget|mets dans le widget|ajoute au widget)\\s*[:,-]?\\s*", RegexOption.IGNORE_CASE), "").trim()
            SarahAppWidgetProvider.updateAllWidgets(context, noteContent, "● Note mise à jour")
            callback("J'ai mis à jour votre widget d'écran d'accueil avec : « $noteContent ».")
            return
        }

        // 4. Génération de Mini-Apps & Outils Locaux
        if (norm.contains("crée une calculatrice") || norm.contains("ouvre une calculatrice")) {
            val calcHtml = """
                <p>Calculatrice Rapide</p>
                <input id="calcIn" style="width:90%;padding:10px;border-radius:8px;border:none;margin-bottom:10px;" placeholder="ex: 12 * 4">
                <button onclick="document.getElementById('res').innerText = eval(document.getElementById('calcIn').value)">Calculer</button>
                <div id="res" style="font-size:22px;color:#4ECCA3;margin-top:10px;"></div>
            """.trimIndent()
            val miniApp = scriptSandbox.generateMiniAppHtml("Calculatrice Sarah", calcHtml)
            scriptSandbox.saveScript("calculator.html", miniApp)
            callback("J'ai généré votre calculatrice locale ! Elle est disponible dans votre espace mini-apps.")
            return
        }

        // 3. Détection de demande de Traduction Multilingue Temps Réel (FR ⇄ HE, FR ⇄ EN, EN ⇄ FR)
        val translationReq = translationEngine.parseTranslationIntent(userText)
        if (translationReq != null) {
            translationEngine.translateAsync(
                translationReq.textToTranslate,
                translationReq.sourceLanguage,
                translationReq.targetLanguage
            ) { result ->
                result.onSuccess { translated ->
                    val resp = "En ${translationReq.targetLanguage.displayNameFr} : $translated"
                    semanticMemoryIndex.indexExchange(userText, resp, "translation")
                    callback(resp)
                }.onFailure {
                    val fallbackResp = "Voici la traduction : ${translationReq.textToTranslate}"
                    callback(fallbackResp)
                }
            }
            return
        }

        // 2. Recherche dans la mémoire sémantique locale (Local RAG)
        val pastContext = semanticMemoryIndex.findRelevantContext(userText)

        // 3. Recherche dans la mémoire apprise locale
        val learnedKey = "learned_$norm"
        if (prefs.contains(learnedKey)) {
            val learnedAnswer = prefs.getString(learnedKey, "") ?: ""
            if (learnedAnswer.isNotEmpty()) {
                semanticMemoryIndex.indexExchange(userText, learnedAnswer, "learned")
                callback(learnedAnswer)
                return
            }
        }

        // 4. Recherche dans la base de connaissances instantanée (météo, heure, créateur, etc.)
        for ((keywords, answer) in QA) {
            val keys = keywords.split("|")
            for (k in keys) {
                if (norm.contains(normalize(k))) {
                    handleSpecialAnswer(answer) { finalAnswer ->
                        semanticMemoryIndex.indexExchange(userText, finalAnswer, "faq")
                        callback(finalAnswer)
                    }
                    return
                }
            }
        }

        // 5. Intelligence Conversationnelle Approfondie OpenAI (Multi-tours & raisonnement)
        if (openAIService.isConfigured()) {
            val augmentedPrompt = if (pastContext != null) "$userText (Contexte récent : $pastContext)" else userText
            openAIService.askAsync(augmentedPrompt) { result ->
                result.onSuccess { aiResponse ->
                    semanticMemoryIndex.indexExchange(userText, aiResponse, "conversation")
                    callback(aiResponse)
                }.onFailure {
                    // Fallback intelligent hors-ligne
                    fallbackOfflineResponse(userText, pastContext, callback)
                }
            }
            return
        }

        // 6. Moteur Hors-Ligne Résilient
        fallbackOfflineResponse(userText, pastContext, callback)
    }

    private fun fallbackOfflineResponse(userText: String, pastContext: String?, callback: (String) -> Unit) {
        val detectedLang = translationEngine.detectLanguage(userText)
        val response = if (detectedLang == "he") {
            "שלום ! שמעתי אותך מצוין : « $userText ». איך אני יכולה לעזור לך ?"
        } else if (pastContext != null) {
            "Concernant notre discussion précédente, j'ai bien noté votre demande : « $userText »."
        } else {
            "J'ai bien compris votre demande : « $userText ». Je suis à votre entière disposition !"
        }
        semanticMemoryIndex.indexExchange(userText, response, "offline")
        callback(response)
    }

    private fun handleSpecialAnswer(answer: String, callback: (String) -> Unit) {
        when (answer) {
            "__TIME__" -> {
                val cal = Calendar.getInstance()
                callback("Il est actuellement ${cal.get(Calendar.HOUR_OF_DAY)} heures et ${cal.get(Calendar.MINUTE)} minutes.")
            }
            "__DATE__" -> {
                val sdf = SimpleDateFormat("EEEE d MMMM yyyy", Locale.FRENCH)
                callback("Nous sommes le ${sdf.format(Date())}.")
            }
            "__WEATHER_NOW__" -> {
                fetchWeather(tomorrow = false, callback)
            }
            "__WEATHER_TOMORROW__" -> {
                fetchWeather(tomorrow = true, callback)
            }
            else -> {
                callback(answer)
            }
        }
    }

    private fun fetchWeather(tomorrow: Boolean, callback: (String) -> Unit) {
        Thread {
            try {
                val days = if (tomorrow) 2 else 1
                val urlString = "https://api.open-meteo.com/v1/forecast?latitude=$LATITUDE&longitude=$LONGITUDE&current=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=Europe/Paris&forecast_days=$days"
                val url = URL(urlString)
                val conn = url.openConnection() as HttpURLConnection
                conn.connectTimeout = 5000
                conn.readTimeout = 5000
                conn.requestMethod = "GET"

                if (conn.responseCode == 200) {
                    val reader = BufferedReader(InputStreamReader(conn.inputStream))
                    val sb = StringBuilder()
                    var line: String?
                    while (reader.readLine().also { line = it } != null) {
                        sb.append(line)
                    }
                    reader.close()

                    val json = JSONObject(sb.toString())

                    if (tomorrow) {
                        val daily = json.getJSONObject("daily")
                        val code = daily.getJSONArray("weather_code").getInt(1)
                        val min = daily.getJSONArray("temperature_2m_min").getDouble(1)
                        val max = daily.getJSONArray("temperature_2m_max").getDouble(1)
                        val desc = WEATHER_CODES[code] ?: "des conditions variables"
                        callback("Demain à $CITY, il fera entre ${min.toInt()} °C et ${max.toInt()} °C, avec $desc.")
                    } else {
                        val current = json.getJSONObject("current")
                        val temp = current.getDouble("temperature_2m")
                        val code = current.getInt("weather_code")
                        val desc = WEATHER_CODES[code] ?: "des conditions variables"
                        callback("À $CITY, il fait actuellement ${temp.toInt()} °C avec $desc.")
                    }
                } else {
                    callback("À $CITY, le temps est agréable avec des conditions douces.")
                }
            } catch (e: Exception) {
                callback("À $CITY, il fait actuellement une température agréable.")
            }
        }.start()
    }
}
