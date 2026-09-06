const os = require('os');
const { execSync } = require('child_process');

/**
 * Détecte avec précision les composants matériels de la machine Windows
 * pour recommander le modèle de génération vidéo IA optimal.
 */
function detectHardware() {
    let cpuName = os.cpus()[0]?.model || 'Processeur Multi-Cœur';
    let gpuName = 'Accélérateur Graphique';
    let totalRAMGB = (os.totalmem() / (1024 ** 3)).toFixed(1);
    let freeRAMGB = (os.freemem() / (1024 ** 3)).toFixed(1);

    // Détection avancée GPU & CPU sous Windows PowerShell
    try {
        if (process.platform === 'win32') {
            const gpuOut = execSync('powershell "Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name"', { encoding: 'utf-8', timeout: 3000 });
            const gpus = gpuOut.trim().split('\n').map(s => s.trim()).filter(Boolean);
            if (gpus.length > 0) {
                gpuName = gpus.join(' / ');
            }
            const cpuOut = execSync('powershell "Get-CimInstance Win32_Processor | Select-Object -ExpandProperty Name"', { encoding: 'utf-8', timeout: 3000 });
            if (cpuOut.trim()) {
                cpuName = cpuOut.trim().split('\n')[0].trim();
            }
        }
    } catch (e) {
        console.warn('Détection PowerShell:', e.message);
    }

    // Analyse du meilleur modèle vidéo IA adapté à cette configuration spécifique
    let recommendedModel = determineOptimalVideoModel(cpuName, gpuName, parseFloat(totalRAMGB));

    return {
        cpu: cpuName,
        gpu: gpuName,
        totalRAMGB: totalRAMGB,
        freeRAMGB: freeRAMGB,
        cores: os.cpus().length,
        os: `${os.type()} ${os.arch()}`,
        recommendedModel: recommendedModel
    };
}

function determineOptimalVideoModel(cpu, gpu, ramGB) {
    const isNvidia = gpu.toLowerCase().includes('nvidia') || gpu.toLowerCase().includes('rtx') || gpu.toLowerCase().includes('gtx');
    const isAMD = gpu.toLowerCase().includes('amd') || gpu.toLowerCase().includes('radeon') || cpu.toLowerCase().includes('ryzen');
    
    if (isNvidia && ramGB >= 16) {
        return {
            id: 'wan-2.1-cuda',
            name: 'Wan 2.1 Video Engine Pro (CUDA RTX / 16:9)',
            size: '4.2 Go',
            description: 'Modèle le plus puissant pour GPU NVIDIA avec rendu cinématique 16:9 et 60fps.',
            recommendedResolution: '1920x1080 (16:9)',
            engine: 'CUDA TensorRT / PyTorch'
        };
    } else if (isAMD || ramGB >= 12) {
        return {
            id: 'wan-2.1-directml-amd',
            name: 'Wan 2.1 Video Ultra-Light (AMD DirectML & Ryzen Multi-Thread)',
            size: '2.8 Go',
            description: 'Modèle ultra-performant optimisé pour votre AMD Ryzen 5 & carte Radeon avec rendu 16:9 fluide sans saturer la RAM.',
            recommendedResolution: '1920x1080 (16:9) & 1280x720',
            engine: 'DirectML / Vulkan / OpenCL'
        };
    } else {
        return {
            id: 'svd-compact-cpu',
            name: 'Stable Video Diffusion Compact (CPU Threaded)',
            size: '1.9 Go',
            description: 'Modèle léger haute vitesse pour processeur standard avec rendu 16:9.',
            recommendedResolution: '1280x720 (16:9)',
            engine: 'CPU Multi-Core'
        };
    }
}

module.exports = { detectHardware };
