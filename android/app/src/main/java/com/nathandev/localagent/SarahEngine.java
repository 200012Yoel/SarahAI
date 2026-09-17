package com.nathandev.localagent;

import android.app.ActivityManager;
import android.content.Context;
import android.os.Build;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Lightweight Android brain used on every device, including low-memory phones.
 * It intentionally has no heavy ML dependency: recent-device AI runtimes can be
 * plugged in later while this engine always remains available as a safe fallback.
 */
public final class SarahEngine {

    public enum DeviceMode {
        LEGACY,
        LITE,
        SMART
    }

    private final Context context;
    private final DeviceMode deviceMode;

    public SarahEngine(Context context) {
        this.context = context.getApplicationContext();
        this.deviceMode = detectDeviceMode(context);
    }

    public DeviceMode getDeviceMode() {
        return deviceMode;
    }

    public String getAgentFor(String prompt) {
        String q = normalize(prompt);
        if (containsAny(q, "traduis", "traduction", "hebreu", "hébreu", "anglais", "english")) {
            return "Yohan";
        }
        if (containsAny(q, "code", "java", "kotlin", "python", "html", "android", "github", "bug")) {
            return "Raphaël";
        }
        if (containsAny(q, "histoire", "geopolitique", "géopolitique", "pays", "guerre", "actualite", "actualité")) {
            return "Tom";
        }
        return "Sarah";
    }

    public String reply(String prompt) {
        String q = normalize(prompt);
        if (q.length() == 0) {
            return "Écris-moi une question. Je suis prête.";
        }

        if (containsAny(q, "bonjour", "salut", "coucou", "hello")) {
            return "Salut 👋 Je suis Sarah. Le moteur Android local fonctionne correctement.";
        }

        if (containsAny(q, "qui es tu", "qui es-tu", "ton nom", "comment tu t'appelles")) {
            return "Je suis Sarah, l'assistante locale de Local agent. Sur les appareils anciens, j'utilise le moteur léger Sarah Engine. Sur les appareils récents, l'application peut activer un moteur IA plus puissant quand il est installé.";
        }

        if (containsAny(q, "mode", "telephone", "téléphone", "appareil", "ram", "version android")) {
            return getDeviceSummary();
        }

        if (containsAny(q, "heure", "quelle heure")) {
            return "Il est " + new SimpleDateFormat("HH:mm", Locale.getDefault()).format(new Date()) + ".";
        }

        if (containsAny(q, "date", "quel jour", "on est quel jour")) {
            return "Nous sommes le " + new SimpleDateFormat("dd/MM/yyyy", Locale.getDefault()).format(new Date()) + ".";
        }

        if (containsAny(q, "hors ligne", "offline", "internet")) {
            return "Sarah Engine fonctionne sans modèle lourd et peut répondre localement aux commandes essentielles. Les fonctions nécessitant des données en direct utilisent Internet uniquement lorsqu'elles sont activées.";
        }

        if (containsAny(q, "traduis bonjour en anglais", "bonjour en anglais")) {
            return "Yohan : « Bonjour » se traduit par « Hello » en anglais.";
        }

        if (containsAny(q, "traduis merci en anglais", "merci en anglais")) {
            return "Yohan : « Merci » se traduit par « Thank you » en anglais.";
        }

        if (containsAny(q, "bonjour en hebreu", "bonjour en hébreu")) {
            return "Yohan : en hébreu, tu peux dire « שלום » (shalom).";
        }

        if (containsAny(q, "merci en hebreu", "merci en hébreu")) {
            return "Yohan : « merci » se dit « תודה » (toda).";
        }

        if (containsAny(q, "raphael", "raphaël", "code")) {
            return "Raphaël : le module développeur Android est chargé. Cette première version de test garde volontairement le moteur léger pour rester stable sur les vieux appareils.";
        }

        if (containsAny(q, "tom", "actualite", "actualité")) {
            return "Tom : je suis disponible dans l'application, mais cette première build n'invente pas d'informations en direct. Le connecteur Web sera branché dans une prochaine étape.";
        }

        if (containsAny(q, "yohan")) {
            return "Yohan : module de traduction prêt. Pour cette première build, les traductions locales essentielles sont actives.";
        }

        if (containsAny(q, "aide", "tu sais faire", "fonctionnalites", "fonctionnalités")) {
            return "Je peux déjà discuter en mode local, identifier Sarah/Tom/Raphaël/Yohan, donner l'heure et la date, détecter les capacités du téléphone et rester fonctionnelle sur un appareil peu puissant. Les moteurs IA lourds seront ajoutés comme option, jamais comme obligation.";
        }

        String agent = getAgentFor(prompt);
        if (deviceMode == DeviceMode.LEGACY) {
            return agent + " : je suis en mode Legacy pour protéger la mémoire de ce téléphone. Sarah Engine reste actif sans charger de gros modèle.";
        }
        if (deviceMode == DeviceMode.LITE) {
            return agent + " : je suis en mode Lite. Le moteur Sarah local répond sans modèle lourd pour garder l'application fluide.";
        }
        return agent + " : Sarah Engine est actif. Ce téléphone est classé Smart et pourra accueillir le moteur IA local dans la prochaine étape.";
    }

    public String getDeviceSummary() {
        long maxMb = Runtime.getRuntime().maxMemory() / (1024L * 1024L);
        return "Mode : " + deviceMode.name()
                + "\nAndroid API : " + Build.VERSION.SDK_INT
                + "\nAppareil : " + Build.MANUFACTURER + " " + Build.MODEL
                + "\nMémoire Java max : ~" + maxMb + " Mo"
                + "\nMoteur de secours : Sarah Engine local";
    }

    private static DeviceMode detectDeviceMode(Context context) {
        long availableMb = 0;
        try {
            ActivityManager manager = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
            if (manager != null) {
                ActivityManager.MemoryInfo info = new ActivityManager.MemoryInfo();
                manager.getMemoryInfo(info);
                availableMb = info.availMem / (1024L * 1024L);
            }
        } catch (Throwable ignored) {
            // Old vendor ROMs can expose incomplete memory information.
        }

        long maxJavaMb = Runtime.getRuntime().maxMemory() / (1024L * 1024L);
        int sdk = Build.VERSION.SDK_INT;

        if (sdk <= 10 || maxJavaMb < 96 || (availableMb > 0 && availableMb < 96)) {
            return DeviceMode.LEGACY;
        }
        if (sdk <= 23 || maxJavaMb < 384 || (availableMb > 0 && availableMb < 384)) {
            return DeviceMode.LITE;
        }
        return DeviceMode.SMART;
    }

    private static boolean containsAny(String value, String... needles) {
        for (int i = 0; i < needles.length; i++) {
            if (value.contains(needles[i])) {
                return true;
            }
        }
        return false;
    }

    private static String normalize(String value) {
        if (value == null) {
            return "";
        }
        return value.trim().toLowerCase(Locale.getDefault());
    }
}
