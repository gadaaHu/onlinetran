import 'package:flutter/material.dart';
import 'face_proctoring_interface.dart';

FaceProctoringPlatform getFaceProctoringPlatform() => FaceProctoringMobile();

class FaceProctoringMobile implements FaceProctoringPlatform {
  @override
  Future<bool> initFaceDetector() async {
    // On mobile, we skip face detection for now since face-api.js is web-only.
    return true; 
  }

  @override
  Future<String?> takeSnapshot(String videoElementId) async {
    // Return null or a mock base64 for mobile if needed.
    return null;
  }

  @override
  Future<bool> matchFace(String videoElementId, String referenceBase64) async {
    // Auto-approve face matching on mobile for now.
    return true;
  }
  
  @override
  Widget buildVideoView(String viewId) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, color: Colors.white54, size: 48),
            SizedBox(height: 16),
            Text(
              "Face proctoring is not yet supported on mobile.",
              style: TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Future<bool> initCamera(String viewId) async {
    return true;
  }

  @override
  void disposeCamera() {
    // No-op on mobile
  }
}
