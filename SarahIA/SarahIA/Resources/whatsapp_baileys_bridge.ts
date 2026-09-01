/**
 * Sarah AI — Passerelle WhatsApp Autonome & Locale (TypeScript Version)
 * Baileys pure WebSocket Client integration
 */

import makeWASocket, {
    useMultiFileAuthState,
    DisconnectReason,
    fetchLatestBaileysVersion,
    makeCacheableSignalKeyStore,
    WASocket,
    proto
} from '@whiskeysockets/baileys';
import pino from 'pino';
import * as path from 'path';
import * as fs from 'fs';
import * as QRCode from 'qrcode';

export interface BridgeEventPayload {
    type: 'status_update' | 'qr_received' | 'connected' | 'logged_out' | 'incoming_message' | 'message_sent' | 'error';
    timestamp: string;
    data: any;
}

export class SarahWhatsAppGateway {
    private sock: WASocket | null = null;
    private authDir: string;
    private isReconnecting = false;
    private reconnectAttempts = 0;
    private readonly maxReconnectAttempts = 10;
    private onEventCallback?: (event: BridgeEventPayload) => void;

    constructor(authDir?: string, onEventCallback?: (event: BridgeEventPayload) => void) {
        this.authDir = authDir || path.join(__dirname, '..', 'Documents', 'WhatsAppAuth');
        this.onEventCallback = onEventCallback;
    }

    private emitEvent(type: BridgeEventPayload['type'], data: any) {
        const payload: BridgeEventPayload = {
            type,
            timestamp: new Date().toISOString(),
            data
        };

        if (this.onEventCallback) {
            this.onEventCallback(payload);
        }

        // Bridge WebKit WKWebView iOS
        if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.sarahWhatsAppBridge) {
            (window as any).webkit.messageHandlers.sarahWhatsAppBridge.postMessage(payload);
        } else if (process.send) {
            process.send(payload);
        } else {
            console.log(`[SARAH_WHATSAPP_EVENT] ${JSON.stringify(payload)}`);
        }
    }

    public async initialize(): Promise<void> {
        try {
            if (!fs.existsSync(this.authDir)) {
                fs.mkdirSync(this.authDir, { recursive: true });
            }

            this.emitEvent('status_update', { status: 'initializing', message: 'Chargement des clés locales...' });

            const { state, saveCreds } = await useMultiFileAuthState(this.authDir);
            const { version, isLatest } = await fetchLatestBaileysVersion();

            this.sock = makeWASocket({
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

            this.sock.ev.on('creds.update', saveCreds);

            this.sock.ev.on('connection.update', async (update) => {
                const { connection, lastDisconnect, qr } = update;

                if (qr) {
                    try {
                        const qrDataUrl = await QRCode.toDataURL(qr, {
                            margin: 2,
                            scale: 8,
                            color: { dark: '#00D9FF', light: '#0D0D12' }
                        });
                        this.emitEvent('qr_received', { qrRaw: qr, qrDataUrl });
                    } catch {
                        this.emitEvent('qr_received', { qrRaw: qr, qrDataUrl: null });
                    }
                }

                if (connection === 'open') {
                    this.reconnectAttempts = 0;
                    this.isReconnecting = false;
                    const user = this.sock?.user;
                    const phoneNumber = user?.id ? user.id.split(':')[0] : 'Inconnu';
                    this.emitEvent('connected', {
                        phoneNumber,
                        pushName: user?.name || 'Sarah Multi-Agent',
                        jid: user?.id
                    });
                }

                if (connection === 'close') {
                    const statusCode = (lastDisconnect?.error as any)?.output?.statusCode;
                    const isLoggedOut = statusCode === DisconnectReason.loggedOut;

                    if (isLoggedOut) {
                        this.emitEvent('logged_out', {
                            message: 'Session déconnectée. Veuillez scanner à nouveau le QR Code.'
                        });
                        try { fs.rmSync(this.authDir, { recursive: true, force: true }); } catch {}
                    } else {
                        this.handleAutoReconnect();
                    }
                }
            });

            this.sock.ev.on('messages.upsert', async ({ messages, type }) => {
                if (type !== 'notify') return;

                for (const msg of messages) {
                    if (!msg.message || msg.key.fromMe) continue;
                    const remoteJid = msg.key.remoteJid;
                    if (!remoteJid || remoteJid === 'status@broadcast') continue;

                    const text = 
                        msg.message.conversation ||
                        msg.message.extendedTextMessage?.text ||
                        msg.message.imageMessage?.caption ||
                        msg.message.videoMessage?.caption ||
                        '';

                    if (!text || text.trim().length === 0) continue;

                    // Marquer comme Lu
                    try { await this.sock?.readMessages([msg.key]); } catch {}

                    // Indicateur de frappe
                    await this.sendTyping(remoteJid);

                    this.emitEvent('incoming_message', {
                        jid: remoteJid,
                        senderName: msg.pushName || 'Contact WhatsApp',
                        text: text.trim(),
                        messageId: msg.key.id,
                        isGroup: remoteJid.endsWith('@g.us')
                    });
                }
            });

        } catch (err: any) {
            this.emitEvent('error', { error: err.message });
            this.handleAutoReconnect();
        }
    }

    private handleAutoReconnect() {
        if (this.isReconnecting) return;
        if (this.reconnectAttempts >= this.maxReconnectAttempts) {
            this.emitEvent('error', { error: 'Nombre maximal de tentatives de reconnexion atteint.' });
            return;
        }

        this.isReconnecting = true;
        this.reconnectAttempts++;
        const delayMs = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000);

        this.emitEvent('status_update', {
            status: 'reconnecting',
            attempt: this.reconnectAttempts,
            delayMs
        });

        setTimeout(() => {
            this.isReconnecting = false;
            this.initialize();
        }, delayMs);
    }

    public async sendTyping(jid: string): Promise<void> {
        if (!this.sock) return;
        try {
            await this.sock.sendPresenceUpdate('composing', jid);
        } catch {}
    }

    public async sendMessage(jid: string, text: string): Promise<proto.WebMessageInfo | undefined> {
        if (!this.sock) throw new Error('Socket WhatsApp non initialisé');
        await this.sock.sendPresenceUpdate('paused', jid);
        const result = await this.sock.sendMessage(jid, { text });
        this.emitEvent('message_sent', { jid, text, messageId: result?.key?.id });
        return result;
    }

    public async logout(): Promise<void> {
        if (this.sock) {
            try {
                await this.sock.logout();
                this.sock = null;
            } catch {}
        }
        try { fs.rmSync(this.authDir, { recursive: true, force: true }); } catch {}
        this.emitEvent('status_update', { status: 'logged_out' });
    }
}
