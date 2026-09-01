/**
 * Sarah AI — Passerelle WhatsApp Autonome & Locale (Baileys Engine)
 * 
 * Moteur pur WebSocket basé sur @whiskeysockets/baileys sans navigateur lourd (sans Puppeteer / Chromium).
 * Fonctionne en local embarqué (Node.js Mobile, JavaScriptCore, ou mini-serveur localhost).
 */

const {
    default: makeWASocket,
    useMultiFileAuthState,
    DisconnectReason,
    fetchLatestBaileysVersion,
    makeCacheableSignalKeyStore,
    delay
} = require('@whiskeysockets/baileys');

const pino = require('pino');
const path = require('path');
const fs = require('fs');
const QRCode = require('qrcode');

// Configuration du répertoire d'authentification local
const AUTH_DIR = process.env.WHATSAPP_AUTH_DIR || path.join(__dirname, '..', 'Documents', 'WhatsAppAuth');
const LOCAL_IPC_PORT = process.env.SARAH_IPC_PORT || 8080;

let sock = null;
let isReconnecting = false;
let reconnectAttempts = 0;
const MAX_RECONNECT_ATTEMPTS = 10;

/**
 * Interface de communication avec l'hôte natif Swift de Sarah
 */
function sendToNativeHost(eventType, payload) {
    const message = {
        type: eventType,
        timestamp: new Date().toISOString(),
        data: payload
    };

    // 1. Bridge WebKit / JavaScriptCore (iOS WKWebView)
    if (typeof window !== 'undefined' && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.sarahWhatsAppBridge) {
        window.webkit.messageHandlers.sarahWhatsAppBridge.postMessage(message);
        return;
    }

    // 2. Node.js process stdout / IPC
    if (process.send) {
        process.send(message);
    } else {
        console.log(`[SARAH_WHATSAPP_EVENT] ${JSON.stringify(message)}`);
    }
}

/**
 * Initialisation du Socket WhatsApp Baileys
 */
async function startSarahWhatsAppBridge() {
    try {
        // Assurer l'existence du dossier de session
        if (!fs.existsSync(AUTH_DIR)) {
            fs.mkdirSync(AUTH_DIR, { recursive: true });
        }

        sendToNativeHost('status_update', { status: 'initializing', message: 'Chargement des clés locales...' });

        // Récupération ou création des clés d'authentification multi-devices
        const { state, saveCreds } = await useMultiFileAuthState(AUTH_DIR);
        const { version, isLatest } = await fetchLatestBaileysVersion();

        console.log(`[Sarah-WhatsApp] Utilisation de Baileys v${version.join('.')} (Dernière: ${isLatest})`);

        sock = makeWASocket({
            version,
            auth: {
                creds: state.creds,
                keys: makeCacheableSignalKeyStore(state.keys, pino({ level: 'silent' }))
            },
            printQRInTerminal: false,
            logger: pino({ level: 'silent' }),
            browser: ['Sarah IA (iPhone)', 'Safari', '18.0'],
            syncFullHistory: false,
            generateHighQualityLinkPreview: true,
            defaultQueryTimeoutMs: 60000,
            keepAliveIntervalMs: 25000
        });

        // 1. Sauvegarde automatique des identifiants et clés de session
        sock.ev.on('creds.update', saveCreds);

        // 2. Gestion des mises à jour de connexion (QR Code, Connecté, Déconnecté)
        sock.ev.on('connection.update', async (update) => {
            const { connection, lastDisconnect, qr } = update;

            // A. Génération du QR Code
            if (qr) {
                try {
                    // Conversion du QR en DataURL base64 pour affichage UI natif
                    const qrDataUrl = await QRCode.toDataURL(qr, {
                        margin: 2,
                        scale: 8,
                        color: {
                            dark: '#00D9FF',
                            light: '#0D0D12'
                        }
                    });

                    sendToNativeHost('qr_received', {
                        qrRaw: qr,
                        qrDataUrl: qrDataUrl
                    });
                } catch (qrErr) {
                    console.error('[Sarah-WhatsApp] Erreur conversion QR Code:', qrErr);
                    sendToNativeHost('qr_received', { qrRaw: qr, qrDataUrl: null });
                }
            }

            // B. Connexion Établie avec succès
            if (connection === 'open') {
                reconnectAttempts = 0;
                isReconnecting = false;
                const user = sock.user || {};
                const phoneNumber = user.id ? user.id.split(':')[0] : 'Inconnu';
                const pushName = user.name || 'Sarah Multi-Agent';

                console.log(`[Sarah-WhatsApp] Connecté avec succès ! Numéro : +${phoneNumber}`);
                sendToNativeHost('connected', {
                    phoneNumber: phoneNumber,
                    pushName: pushName,
                    jid: user.id
                });
            }

            // C. Connexion Fermée / Déconnexion
            if (connection === 'close') {
                const statusCode = lastDisconnect?.error?.output?.statusCode;
                const isLoggedOut = statusCode === DisconnectReason.loggedOut;

                console.warn(`[Sarah-WhatsApp] Connexion fermée. Code: ${statusCode} (Déconnecté: ${isLoggedOut})`);

                if (isLoggedOut) {
                    sendToNativeHost('logged_out', {
                        message: 'Session déconnectée depuis WhatsApp. Veuillez rescanner le QR Code.'
                    });
                    // Nettoyage des credentials expirés
                    try {
                        fs.rmSync(AUTH_DIR, { recursive: true, force: true });
                    } catch (e) {}
                } else {
                    // Reconnexion automatique avec backoff
                    handleAutoReconnect();
                }
            }
        });

        // 3. Écoute des Messages Entrants (upsert)
        sock.ev.on('messages.upsert', async ({ messages, type }) => {
            if (type !== 'notify') return;

            for (const msg of messages) {
                // Filtrer les messages système ou envoyés par Sarah elle-même
                if (!msg.message || msg.key.fromMe) continue;

                const remoteJid = msg.key.remoteJid;
                // Ignorer les statuts broadcast ou groupes si non désiré
                if (!remoteJid || remoteJid === 'status@broadcast') continue;

                // Extraction du texte depuis différents types de messages (texte simple, étendu, légende média)
                const text = 
                    msg.message.conversation ||
                    msg.message.extendedTextMessage?.text ||
                    msg.message.imageMessage?.caption ||
                    msg.message.videoMessage?.caption ||
                    '';

                // Gestion des Messages Vocaux / Audio Entrants (PTT)
                if (msg.message.audioMessage) {
                    const senderName = msg.pushName || 'Contact WhatsApp';
                    console.log(`[Sarah-WhatsApp] Message vocal entrant de ${senderName} (${remoteJid})`);
                    try { await sock.readMessages([msg.key]); } catch (e) {}
                    
                    sendToNativeHost('incoming_audio_message', {
                        jid: remoteJid,
                        senderName: senderName,
                        duration: msg.message.audioMessage.seconds || 0,
                        isPtt: msg.message.audioMessage.ptt || false,
                        messageId: msg.key.id
                    });
                    continue;
                }

                if (!text || text.trim().length === 0) continue;

                const senderName = msg.pushName || 'Contact WhatsApp';
                const messageId = msg.key.id;

                console.log(`[Sarah-WhatsApp] Message entrant de ${senderName} (${remoteJid}) : "${text}"`);

                // A. Marquer le message comme Lu (double coche bleue)
                try {
                    await sock.readMessages([msg.key]);
                } catch (e) {}

                // B. Envoyer l'état "En train d'écrire..." (Typing indicator)
                await sendTyping(remoteJid);

                // C. Transmettre au pipeline d'inférence de Sarah en Swift
                sendToNativeHost('incoming_message', {
                    jid: remoteJid,
                    senderName: senderName,
                    text: text.trim(),
                    messageId: messageId,
                    isGroup: remoteJid.endsWith('@g.us')
                });
            }
        });

    } catch (err) {
        console.error('[Sarah-WhatsApp] Erreur critique initialisation:', err);
        sendToNativeHost('error', { error: err.message });
        handleAutoReconnect();
    }
}

/**
 * Reconnexion automatique avec backoff exponentiel
 */
function handleAutoReconnect() {
    if (isReconnecting) return;
    if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
        sendToNativeHost('error', { error: 'Nombre maximal de tentatives de reconnexion atteint.' });
        return;
    }

    isReconnecting = true;
    reconnectAttempts++;
    const delayMs = Math.min(1000 * Math.pow(2, reconnectAttempts), 30000);

    sendToNativeHost('status_update', {
        status: 'reconnecting',
        attempt: reconnectAttempts,
        delayMs: delayMs
    });

    setTimeout(() => {
        isReconnecting = false;
        startSarahWhatsAppBridge();
    }, delayMs);
}

/**
 * Envoie l'indicateur de saisie "composing..." sur le chat
 */
async function sendTyping(jid) {
    if (!sock) return;
    try {
        await sock.sendPresenceUpdate('composing', jid);
    } catch (e) {
        console.error('[Sarah-WhatsApp] Erreur sendTyping:', e);
    }
}

/**
 * Envoie l'indicateur d'enregistrement vocal "recording..." sur le chat
 */
async function sendRecordingPresence(jid) {
    if (!sock) return;
    try {
        await sock.sendPresenceUpdate('recording', jid);
    } catch (e) {
        console.error('[Sarah-WhatsApp] Erreur sendRecordingPresence:', e);
    }
}

/**
 * Envoie un message vocal PTT (Opus / AAC) avec garde-fous anti-ban (jitter 1.5s - 3.5s + présence 'recording')
 * Piloté par Nathan (dispatching WhatsApp) et vocalement généré par Yoann / Sarah
 */
async function sendVoiceNote(jid, base64AudioData, durationSeconds = 3) {
    if (!sock) {
        throw new Error('Socket WhatsApp non initialisé');
    }
    try {
        console.log(`[Sarah-WhatsApp/Nathan] Préparation d'envoi du vocal PTT vers ${jid}...`);
        
        // 1. Présence réaliste "En train d'enregistrer un audio..."
        await sock.sendPresenceUpdate('recording', jid);
        
        // 2. Garde-fou Anti-Ban : Jitter humain réaliste aléatoire entre 1.5s et 3.5s
        const jitterMs = Math.floor(Math.random() * (3500 - 1500 + 1)) + 1500;
        await delay(jitterMs);
        
        // 3. Conversion du buffer audio
        const audioBuffer = Buffer.from(base64AudioData, 'base64');
        
        // 4. Envoi du Push-To-Talk (PTT)
        const result = await sock.sendMessage(jid, {
            audio: audioBuffer,
            mimetype: 'audio/mp4',
            ptt: true,
            seconds: durationSeconds
        });
        
        // 5. Réinitialisation de l'état de présence
        await sock.sendPresenceUpdate('paused', jid);
        
        sendToNativeHost('voice_note_sent', {
            jid: jid,
            duration: durationSeconds,
            messageId: result?.key?.id
        });
        
        console.log(`[Sarah-WhatsApp/Nathan] Vocal PTT transmis avec succès à ${jid} !`);
        return result;
    } catch (err) {
        console.error(`[Sarah-WhatsApp/Nathan] Échec envoi vocal vers ${jid}:`, err);
        sendToNativeHost('error', { error: `Échec d'envoi du vocal: ${err.message}` });
        throw err;
    }
}

/**
 * Envoie la réponse textuelle générée par Sarah directement sur le socket WhatsApp
 */
async function sendMessage(jid, text) {
    if (!sock) {
        throw new Error('Socket WhatsApp non initialisé');
    }
    try {
        // Arrêter l'état de saisie
        await sock.sendPresenceUpdate('paused', jid);
        
        // Envoi du message
        const result = await sock.sendMessage(jid, { text: text });
        
        sendToNativeHost('message_sent', {
            jid: jid,
            text: text,
            messageId: result?.key?.id
        });
        return result;
    } catch (err) {
        console.error(`[Sarah-WhatsApp] Échec d'envoi vers ${jid}:`, err);
        sendToNativeHost('error', { error: `Échec d'envoi du message: ${err.message}` });
        throw err;
    }
}

/**
 * Déconnexion propre de la session
 */
async function logout() {
    if (sock) {
        try {
            await sock.logout();
            sock = null;
        } catch (e) {}
    }
    try {
        fs.rmSync(AUTH_DIR, { recursive: true, force: true });
    } catch (e) {}
    sendToNativeHost('status_update', { status: 'logged_out' });
}

// Export pour utilisation en module Node ou script exécutable
module.exports = {
    startSarahWhatsAppBridge,
    sendTyping,
    sendRecordingPresence,
    sendVoiceNote,
    sendMessage,
    logout
};

// Démarrage automatique si exécuté directement
if (require.main === module) {
    startSarahWhatsAppBridge();
}
