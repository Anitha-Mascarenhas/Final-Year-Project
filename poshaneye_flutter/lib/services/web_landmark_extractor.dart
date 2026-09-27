import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/services.dart';

Future<Map<dynamic, dynamic>?>? _initialization;

@JS('PoshanEyeLandmarks.initialize')
external JSPromise<JSAny?> _initializeDetector(
    JSString faceModel, JSString poseModel);

@JS('PoshanEyeLandmarks.detect')
external JSPromise<JSAny?> _detectFrame(JSString jpegBase64);

Future<Map<dynamic, dynamic>?> extract(Uint8List imageBytes) async {
  await (_initialization ??= _initialize());
  final result = await _detectFrame(base64Encode(imageBytes).toJS).toDart;
  final decoded = result.dartify();
  if (decoded is Map) return Map<dynamic, dynamic>.from(decoded);
  throw PlatformException(
      code: 'landmark_result_invalid', message: 'Invalid landmark result');
}

Future<Map<dynamic, dynamic>?> _initialize() async {
  final faceData = await rootBundle.load('assets/models/face_landmarker.task');
  final poseData = await rootBundle.load('assets/models/pose_landmarker.task');
  final faceBase64 = base64Encode(faceData.buffer
      .asUint8List(faceData.offsetInBytes, faceData.lengthInBytes));
  final poseBase64 = base64Encode(poseData.buffer
      .asUint8List(poseData.offsetInBytes, poseData.lengthInBytes));
  await _initializeDetector(faceBase64.toJS, poseBase64.toJS).toDart;
  return null;
}
