// ignore_for_file: avoid_web_libraries_in_flutter, uri_does_not_exist, undefined_function
@JS()
library face_api_interop;

import 'package:js/js.dart';
import 'dart:js_util';

@JS('initFaceDetector')
external Object _initFaceDetector();

@JS('detectFaces')
external Object _detectFaces(String videoElementId);

@JS('takeSnapshot')
external Object _takeSnapshot(String videoElementId);

@JS('matchFace')
external Object _matchFace(String videoElementId, String profilePicUrl);

Future<bool> initFaceDetector() async {
  final promise = _initFaceDetector();
  try {
    final result = await promiseToFuture<bool>(promise);
    return result;
  } catch (e) {
    return false;
  }
}

Future<int> detectFaces(String videoElementId) async {
  final promise = _detectFaces(videoElementId);
  try {
    final numResult = await promiseToFuture<num>(promise);
    return numResult.toInt();
  } catch (e) {
    return -1;
  }
}

Future<String?> takeSnapshot(String videoElementId) async {
  final promise = _takeSnapshot(videoElementId);
  try {
    final result = await promiseToFuture<dynamic>(promise);
    if (result == null) return null;
    return result.toString();
  } catch (e) {
    return null;
  }
}

Future<bool> matchFace(String videoElementId, String profilePicUrl) async {
  final promise = _matchFace(videoElementId, profilePicUrl);
  try {
    final result = await promiseToFuture<bool>(promise);
    return result;
  } catch (e) {
    return false;
  }
}
