/**
 * Sarah PC Companion Server — Dédié Exclusivement à la Génération Vidéo IA
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');
const { detectHardware } = require('./hardware');
const { getModelStatus, installRecommendedModel } = require('./model-manager');
const { processVideoJob, getActiveJobs, getVideoHistory } = require('./video-engine');

const PORT = process.env.PORT || 8080;
const PAIRING_TOKEN = crypto.randomBytes(3).toString('hex').toUpperCase(); // PIN 6 caractères
let connectedDevices = [];

// Détection de l'IP LAN
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
const PC_NAME = `${os.hostname()} (Sarah PC Workstation)`;

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

    // 1. Diagnostic Matériel Complet
    if (pathname === '/api/hardware' && req.method === 'GET') {
        const hw = detectHardware();
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(hw));
        return;
    }

    // 2. Statut du Modèle Unique Détecté
    if (pathname === '/api/model/status' && req.method === 'GET') {
        const status = getModelStatus();
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(status));
        return;
    }

    // 3. Téléchargement & Installation en 1 Clic du Modèle Unique
    if (pathname === '/api/model/install' && req.method === 'POST') {
        installRecommendedModel();
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'installing' }));
        return;
    }

    // 4. Statut Général pour le Jumelage iPhone
    if (pathname === '/api/status' && req.method === 'GET') {
        const hw = detectHardware();
        const modelInfo = getModelStatus();
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            status: 'ok',
            name: PC_NAME,
            ip: localIP,
            port: PORT,
            token: PAIRING_TOKEN,
            qrString: `sarahpc://${localIP}:${PORT}?token=${PAIRING_TOKEN}&name=${encodeURIComponent(PC_NAME)}`,
            hardware: hw,
            model: modelInfo.currentModel,
            modelInstalled: modelInfo.installed,
            gpu: `${hw.gpu} (Rendu Vidéo 16:9 Prêt)`,
            connectedClients: connectedDevices.length,
            purpose: 'Génération Vidéo Déportée Exclusivement (Photos en local sur iPhone)'
        }));
        return;
    }

    // 5. Jumelage depuis l'iPhone
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
                console.log(`📱 [Sarah PC] iPhone appairé avec succès pour le rendu vidéo : ${clientDevice}`);
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ status: 'paired', pcName: PC_NAME }));
            } catch (err) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: err.message }));
            }
        });
        return;
    }

    // 6. Génération Vidéo IA Déportée (16:9 PC, 9:16, 1:1)
    if (pathname === '/api/generate-video' && req.method === 'POST') {
        let body = '';
        req.on('data', chunk => body += chunk);
        req.on('end', () => {
            try {
                const data = JSON.parse(body || '{}');
                const prompt = data.prompt || 'Cinematic video 16:9';
                const ratio = data.ratio || '16:9';

                console.log(`🎬 [Video Engine PC] Lancement du rendu vidéo : "${prompt}" (${ratio})`);

                const job = processVideoJob(prompt, ratio);

                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify(job));
            } catch (err) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: err.message }));
            }
        });
        return;
    }

    // 7. Liste des Vidéos Récentes
    if (pathname === '/api/videos' && req.method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            active: getActiveJobs(),
            history: getVideoHistory()
        }));
        return;
    }

    // --- Fichiers Statiques Desktop Web UI ---
    let filePath = path.join(__dirname, 'public', pathname === '/' ? 'index.html' : pathname);
    const ext = path.extname(filePath).toLowerCase();

    fs.readFile(filePath, (err, content) => {
        if (err) {
            if (err.code === 'ENOENT') {
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

const hw = detectHardware();
server.listen(PORT, '0.0.0.0', () => {
    console.log(`\n======================================================`);
    console.log(`   ✨ SARAH IA — LOGICIEL PC & STUDIO VIDÉO DÉPORTÉ`);
    console.log(`======================================================`);
    console.log(`💻 Composants Détectés :`);
    console.log(`   - Processeur : ${hw.cpu} (${hw.cores} cœurs)`);
    console.log(`   - Mémoire RAM : ${hw.totalRAMGB} Go (${hw.freeRAMGB} Go libres)`);
    console.log(`   - Graphique : ${hw.gpu}`);
    console.log(`🔥 Modèle Vidéo Optimal Détecté : ${hw.recommendedModel.name}`);
    console.log(`------------------------------------------------------`);
    console.log(`🌐 Interface Logiciel PC : http://localhost:${PORT}`);
    console.log(`📱 Connexion iPhone (QR Code) : http://${localIP}:${PORT}`);
    console.log(`🔑 Code PIN Jumelage : ${PAIRING_TOKEN}`);
    console.log(`🎯 Usage Exclusif : Génération Vidéo 16:9 PC (Photos en local sur iPhone)`);
    console.log(`======================================================\n`);
});
