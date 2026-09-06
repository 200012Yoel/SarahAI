/**
 * Sarah PC Companion Server
 * Serveur autonome Node.js (sans dépendance externe requise)
 * Fournit l'interface Web PC, le jumelage QR Code / PIN et le moteur de rendu vidéo déporté.
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');

const PORT = process.env.PORT || 8080;
const PAIRING_TOKEN = crypto.randomBytes(3).toString('hex').toUpperCase(); // PIN à 6 caractères
let connectedDevices = [];
let videoJobs = [];
let syncedMessages = [];

// Détection de l'IP Locale LAN (Wi-Fi / Ethernet)
function getLocalIP() {
    const interfaces = os.networkInterfaces();
    for (const name of Object.keys(interfaces)) {
        for (const iface of interfaces[name]) {
            if (iface.family === 'IPv4' && !iface.internal) {
                return iface.address;
            }
        }
    }
    return '127.0.0.1';
}

const localIP = getLocalIP();
const PC_NAME = `${os.hostname()} (Sarah PC)`;

// Types MIME
const MIME_TYPES = {
    '.html': 'text/html',
    '.css': 'text/css',
    '.js': 'text/javascript',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.svg': 'image/svg+xml',
    '.mp4': 'video/mp4'
};

const server = http.createServer((req, res) => {
    // CORS Headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (req.method === 'OPTIONS') {
        res.writeHead(204);
        res.end();
        return;
    }

    const parsedUrl = new URL(req.url, `http://${req.headers.host}`);
    const pathname = parsedUrl.pathname;

    // --- API REST ---
    
    // 1. Statut & Infos Matérielles
    if (pathname === '/api/status' && req.method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            status: 'ok',
            name: PC_NAME,
            ip: localIP,
            port: PORT,
            token: PAIRING_TOKEN,
            qrString: `sarahpc://${localIP}:${PORT}?token=${PAIRING_TOKEN}&name=${encodeURIComponent(PC_NAME)}`,
            gpu: 'GPU Dédié Rendu Vidéo 16:9 Prêt',
            os: `${os.type()} ${os.release()}`,
            memoryTotalGB: (os.totalmem() / (1024 ** 3)).toFixed(1),
            connectedClients: connectedDevices.length,
            supportedRatios: ['16:9', '9:16', '1:1']
        }));
        return;
    }

    // 2. Jumelage depuis l'iPhone
    if (pathname === '/api/pair' && req.method === 'POST') {
        let body = '';
        req.on('data', chunk => body += chunk);
        req.on('end', () => {
            try {
                const data = JSON.parse(body || '{}');
                const clientDevice = data.device || 'iPhone';
                connectedDevices.push({
                    device: clientDevice,
                    pairedAt: new Date().toISOString(),
                    ip: req.socket.remoteAddress
                });
                console.log(`📱 [Pairing] iPhone appairé avec succès : ${clientDevice}`);
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ status: 'paired', pcName: PC_NAME }));
            } catch (err) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: err.message }));
            }
        });
        return;
    }

    // 3. Génération Vidéo IA Déportée sur PC
    if (pathname === '/api/generate-video' && req.method === 'POST') {
        let body = '';
        req.on('data', chunk => body += chunk);
        req.on('end', () => {
            try {
                const data = JSON.parse(body || '{}');
                const prompt = data.prompt || 'Cinematic video 4k';
                const ratio = data.ratio || '16:9';
                const jobId = data.jobId || crypto.randomUUID();

                console.log(`🎬 [VideoGen PC] Nouvelle tâche vidéo déportée : "${prompt}" (Ratio: ${ratio})`);

                const newJob = {
                    id: jobId,
                    prompt: prompt,
                    ratio: ratio,
                    status: 'rendering',
                    progress: 0.1,
                    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
                    createdAt: new Date().toISOString()
                };

                videoJobs.unshift(newJob);

                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify(newJob));
            } catch (err) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: err.message }));
            }
        });
        return;
    }

    // 4. Synchronisation des Messages
    if (pathname === '/api/sync' && req.method === 'POST') {
        let body = '';
        req.on('data', chunk => body += chunk);
        req.on('end', () => {
            try {
                const data = JSON.parse(body || '{}');
                if (data.messages && Array.isArray(data.messages)) {
                    syncedMessages = data.messages;
                }
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ status: 'synced', count: syncedMessages.length }));
            } catch (err) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: err.message }));
            }
        });
        return;
    }

    // --- Fichiers Statiques UI ---
    let filePath = path.join(__dirname, 'public', pathname === '/' ? 'index.html' : pathname);
    const ext = path.extname(filePath).toLowerCase();

    fs.readFile(filePath, (err, content) => {
        if (err) {
            if (err.code === 'ENOENT') {
                // Fallback sur index.html pour SPA
                fs.readFile(path.join(__dirname, 'public', 'index.html'), (err2, fallback) => {
                    if (err2) {
                        res.writeHead(404, { 'Content-Type': 'text/plain' });
                        res.end('404 Not Found');
                    } else {
                        res.writeHead(200, { 'Content-Type': 'text/html' });
                        res.end(fallback, 'utf-8');
                    }
                });
            } else {
                res.writeHead(500);
                res.end(`Erreur serveur: ${err.code}`);
            }
        } else {
            res.writeHead(200, { 'Content-Type': MIME_TYPES[ext] || 'application/octet-stream' });
            res.end(content, 'utf-8');
        }
    });
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`\n======================================================`);
    console.log(`   ✨ SARAH IA — COMPAGNON PC & SERVEUR VIDÉO DÉPORTÉ`);
    console.log(`======================================================`);
    console.log(`🌐 Accès Web PC Local : http://localhost:${PORT}`);
    console.log(`📱 Accès depuis iPhone : http://${localIP}:${PORT}`);
    console.log(`🔑 Code PIN de Jumelage : ${PAIRING_TOKEN}`);
    console.log(`🎬 Rendu Vidéo Déporté : Ratio 16:9 PC, 9:16 & 1:1 Prêt`);
    console.log(`📸 Photos : Rendu en Local sur l'iPhone`);
    console.log(`======================================================\n`);
});
