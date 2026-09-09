import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:ui_web' as ui_web;
import 'dart:async';
import '../face_api_interop.dart' as face_api;
import 'face_proctoring_interface.dart';

FaceProctoringPlatform getFaceProctoringPlatform() => FaceProctoringWeb();

class FaceProctoringWeb implements FaceProctoringPlatform {
  html.VideoElement? _videoElement;
  html.MediaStream? _mediaStream;
  
  @override
  Future<bool> initFaceDetector() async {
    return await face_api.initFaceDetector();
  }

  @override
  Future<String?> takeSnapshot(String videoElementId) async {
    return await face_api.takeSnapshot(videoElementId);
  }

  @override
  Future<bool> matchFace(String videoElementId, String referenceBase64) async {
    return await face_api.matchFace(videoElementId, referenceBase64);
  }
  
  @override
  Widget buildVideoView(String viewId) {
    return HtmlElementView(viewType: viewId);
  }

  @override
  Future<bool> initCamera(String viewId) async {
    _videoElement = html.VideoElement()
      ..id = viewId
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover';

    try {
      ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) => _videoElement!);
    } catch (_) {}

    try {
      if (html.window.navigator.mediaDevices == null) {
        return false;
      }
      final mediaStream = await html.window.navigator.mediaDevices!.getUserMedia({'video': true, 'audio': false});
      _mediaStream = mediaStream;
      _videoElement!.srcObject = mediaStream;

      final completer = Completer<void>();
      _videoElement!.onLoadedData.first.then((_) {
        if (!completer.isCompleted) completer.complete();
      });
      _videoElement!.onCanPlay.first.then((_) {
        if (!completer.isCompleted) completer.complete();
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (!completer.isCompleted) completer.complete();
      });

      await completer.future;
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  void disposeCamera() {
    if (_mediaStream != null) {
      for (var track in _mediaStream!.getTracks()) {
        track.stop();
      }
      _mediaStream = null;
    }
    if (_videoElement != null) {
      _videoElement!.srcObject = null;
      _videoElement = null;
    }
  }
}
