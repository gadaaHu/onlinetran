import 'package:flutter/widgets.dart';

abstract class FaceProctoringPlatform {
  Future<bool> initFaceDetector();
  Future<String?> takeSnapshot(String videoElementId);
  Future<bool> matchFace(String videoElementId, String referenceBase64);
  
  Widget buildVideoView(String viewId);
  Future<bool> initCamera(String viewId);
  void disposeCamera();
}
