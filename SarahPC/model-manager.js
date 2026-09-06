const fs = require('fs');
const path = require('path');
const { detectHardware } = require('./hardware');

const MODELS_DIR = path.join(__dirname, 'models');
if (!fs.existsSync(MODELS_DIR)) {
    fs.mkdirSync(MODELS_DIR, { recursive: true });
}

let modelState = {
    installed: false,
    downloading: false,
    progress: 0,
    currentModel: null,
    statusText: 'Prêt à installer le modèle optimisé'
};

function getModelStatus() {
    const hw = detectHardware();
    const targetModel = hw.recommendedModel;
    const modelConfigFile = path.join(MODELS_DIR, `${targetModel.id}.json`);

    if (fs.existsSync(modelConfigFile) && !modelState.downloading) {
        modelState.installed = true;
        modelState.currentModel = targetModel;
        modelState.statusText = 'Modèle opérationnel dans la mémoire PC';
    } else if (!modelState.downloading) {
        modelState.currentModel = targetModel;
    }

    return {
        ...modelState,
        hardware: hw
    };
}

function installRecommendedModel(onProgress, onComplete) {
    const hw = detectHardware();
    const targetModel = hw.recommendedModel;

    modelState.downloading = true;
    modelState.installed = false;
    modelState.progress = 0;
    modelState.statusText = `Téléchargement et configuration de ${targetModel.name}...`;

    // Simulation de téléchargement et initialisation optimisée DirectML / GPU
    let currentProgress = 0;
    const timer = setInterval(() => {
        currentProgress += 12;
        modelState.progress = Math.min(100, currentProgress);

        if (currentProgress < 50) {
            modelState.statusText = `Téléchargement des poids du modèle (${modelState.progress}%)...`;
        } else if (currentProgress < 90) {
            modelState.statusText = `Optimisation des tenseurs pour ${hw.gpu} & ${hw.cpu}...`;
        } else {
            modelState.statusText = `Chargement du pipeline vidéo 16:9 dans la mémoire...`;
        }

        if (onProgress) onProgress(modelState);

        if (currentProgress >= 100) {
            clearInterval(timer);
            modelState.downloading = false;
            modelState.installed = true;
            modelState.progress = 100;
            modelState.statusText = `✅ ${targetModel.name} installé et prêt pour le rendu vidéo 16:9 !`;

            // Sauvegarde de l'état
            const modelConfigFile = path.join(MODELS_DIR, `${targetModel.id}.json`);
            fs.writeFileSync(modelConfigFile, JSON.stringify({
                id: targetModel.id,
                name: targetModel.name,
                installedAt: new Date().toISOString(),
                hardware: hw
            }, null, 2));

            if (onComplete) onComplete(modelState);
        }
    }, 400);
}

module.exports = {
    getModelStatus,
    installRecommendedModel
};
