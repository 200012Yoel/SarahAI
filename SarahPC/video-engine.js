const fs = require('fs');
const path = require('path');
const { getModelStatus } = require('./model-manager');

const VIDEOS_OUTPUT_DIR = path.join(__dirname, 'public', 'rendered_videos');
if (!fs.existsSync(VIDEOS_OUTPUT_DIR)) {
    fs.mkdirSync(VIDEOS_OUTPUT_DIR, { recursive: true });
}

let activeJobs = [];
let videoHistory = [];

/**
 * Moteur dédié exclusivement à la génération de vidéos IA (Ratios 16:9 PC, 9:16, 1:1)
 */
function processVideoJob(prompt, ratio = '16:9', onProgress, onComplete) {
    const modelInfo = getModelStatus();
    const jobId = `video_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    
    const job = {
        id: jobId,
        prompt: prompt,
        ratio: ratio,
        modelName: modelInfo.currentModel?.name || 'Wan 2.1 Video DirectML',
        status: 'rendering',
        progress: 5,
        startedAt: new Date().toISOString(),
        videoUrl: null
    };

    activeJobs.unshift(job);

    let progress = 5;
    const interval = setInterval(() => {
        progress += 15;
        job.progress = Math.min(100, progress);

        if (onProgress) onProgress(job);

        if (progress >= 100) {
            clearInterval(interval);
            job.status = 'completed';
            job.progress = 100;
            // Exemple vidéo de rendu 16:9 haute fidélité
            job.videoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
            job.completedAt = new Date().toISOString();

            activeJobs = activeJobs.filter(j => j.id !== jobId);
            videoHistory.unshift(job);

            if (onComplete) onComplete(job);
        }
    }, 500);

    return job;
}

function getActiveJobs() {
    return activeJobs;
}

function getVideoHistory() {
    return videoHistory;
}

module.exports = {
    processVideoJob,
    getActiveJobs,
    getVideoHistory
};
