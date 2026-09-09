let modelsLoaded = false;

async function initFaceDetector() {
  if (modelsLoaded) return true;
  try {
    // Load models from CDN
    const modelUrl = 'https://cdn.jsdelivr.net/npm/@vladmandic/face-api/model/';
    await Promise.all([
        faceapi.nets.tinyFaceDetector.loadFromUri(modelUrl),
        faceapi.nets.faceLandmark68Net.loadFromUri(modelUrl),
        faceapi.nets.faceRecognitionNet.loadFromUri(modelUrl)
    ]);
    modelsLoaded = true;
    console.log("FaceAPI models loaded successfully.");
    return true;
  } catch (e) {
    console.error("Failed to load FaceAPI models:", e);
    return false;
  }
}

function _getVideoElement(videoElementId) {
    // Recursive search through all shadow roots
    function searchDOM(root) {
        if (!root) return null;
        
        // Check current root
        let video = root.getElementById ? root.getElementById(videoElementId) : null;
        if (!video && root.querySelector) video = root.querySelector(`video[id="${videoElementId}"]`);
        if (!video && root.querySelector) video = root.querySelector('video');
        if (video) return video;

        // Traverse children and their shadow roots
        const children = root.children || root.childNodes;
        if (children) {
            for (let i = 0; i < children.length; i++) {
                const child = children[i];
                if (child.shadowRoot) {
                    const found = searchDOM(child.shadowRoot);
                    if (found) return found;
                }
                const foundChild = searchDOM(child);
                if (foundChild) return foundChild;
            }
        }
        return null;
    }

    return searchDOM(document.body);
}

async function detectFaces(videoElementId) {
  if (!modelsLoaded) {
    console.warn("Models not loaded yet.");
    return -1;
  }
  try {
    const video = _getVideoElement(videoElementId);
    if (!video || video.ended || video.readyState < 2) return -1;
    const detections = await faceapi.detectAllFaces(video, new faceapi.TinyFaceDetectorOptions());
    return detections.length;
  } catch (e) {
    console.error("Error during face detection:", e);
    return -1;
  }
}

async function takeSnapshot(videoElementId) {
    try {
        const video = _getVideoElement(videoElementId);
    if (!video || video.ended || video.readyState < 2) {
        console.error("takeSnapshot failed: video state invalid", { 
            hasVideo: !!video, 
            ended: video ? video.ended : null, 
            readyState: video ? video.readyState : null 
        });
        return null;
    }
        
        const canvas = document.createElement('canvas');
        canvas.width = video.videoWidth;
        canvas.height = video.videoHeight;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
        
        return canvas.toDataURL('image/jpeg', 0.8);
    } catch(e) {
        console.error("Error taking snapshot:", e);
        return null;
    }
}

async function matchFace(videoElementId, profilePicUrl) {
    if (!modelsLoaded) return false;
    try {
        const video = _getVideoElement(videoElementId);
        if (!video || video.ended || video.readyState < 2) return false;

        // Fetch profile image and get descriptor
        const profileImg = await faceapi.fetchImage(profilePicUrl);
        const profileDetection = await faceapi.detectSingleFace(profileImg, new faceapi.TinyFaceDetectorOptions()).withFaceLandmarks().withFaceDescriptor();
        
        if (!profileDetection) {
            console.error("Could not detect face in profile picture.");
            return false; 
        }

        // Get descriptor from live video
        const videoDetection = await faceapi.detectSingleFace(video, new faceapi.TinyFaceDetectorOptions()).withFaceLandmarks().withFaceDescriptor();

        if (!videoDetection) {
            console.warn("No face detected in live video.");
            return false;
        }

        // Compare
        const distance = faceapi.euclideanDistance(profileDetection.descriptor, videoDetection.descriptor);
        console.log("Face distance:", distance);
        return distance < 0.6;
    } catch(e) {
        console.error("Error matching face:", e);
        return false;
    }
}

window.initFaceDetector = initFaceDetector;
window.detectFaces = detectFaces;
window.takeSnapshot = takeSnapshot;
window.matchFace = matchFace;
