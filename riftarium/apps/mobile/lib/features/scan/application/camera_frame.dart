import 'dart:io';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Conversion d'une image du flux caméra en image ML Kit.
///
/// Un seul plan de part et d'autre, ce qui évite de recomposer un tampon à
/// chaque image (3 fois par seconde sur un flux 720p) :
/// - Android : NV21, que CameraX sait produire directement et que ML Kit
///   accepte tel quel ;
/// - iOS : BGRA8888, le format natif de l'AVFoundation.
ImageFormatGroup get scanImageFormat =>
    Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888;

/// Compensation à appliquer à l'orientation du capteur selon la façon dont
/// l'appareil est tenu (table de l'exemple officiel de google_mlkit).
const Map<DeviceOrientation, int> _deviceRotations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// Rotation à déclarer à ML Kit pour que le texte soit lu à l'endroit.
///
/// iOS gère la rotation lui-même à partir de l'orientation du capteur ; Android
/// attend l'angle réel entre le capteur et l'écran, et le sens de la
/// composition s'inverse pour la caméra frontale (image en miroir).
InputImageRotation? scanRotation({
  required int sensorOrientation,
  required CameraLensDirection lensDirection,
  required DeviceOrientation deviceOrientation,
}) {
  if (Platform.isIOS) {
    return InputImageRotationValue.fromRawValue(sensorOrientation);
  }
  final compensation = _deviceRotations[deviceOrientation];
  if (compensation == null) return null;
  final degrees = lensDirection == CameraLensDirection.front
      ? (sensorOrientation + compensation) % 360
      : (sensorOrientation - compensation + 360) % 360;
  return InputImageRotationValue.fromRawValue(degrees);
}

/// Image du flux → [InputImage], ou null quand le format reçu n'est pas celui
/// demandé (l'appareil a imposé le sien) : mieux vaut sauter l'image que
/// donner à ML Kit des octets qu'il interprétera de travers.
InputImage? inputImageFrom(
  CameraImage image, {
  required CameraDescription description,
  required DeviceOrientation deviceOrientation,
}) {
  final rotation = scanRotation(
    sensorOrientation: description.sensorOrientation,
    lensDirection: description.lensDirection,
    deviceOrientation: deviceOrientation,
  );
  if (rotation == null) return null;

  final raw = image.format.raw;
  if (raw is! int) return null;
  final format = InputImageFormatValue.fromRawValue(raw);
  if (format == null) return null;
  final expected = Platform.isAndroid
      ? InputImageFormat.nv21
      : InputImageFormat.bgra8888;
  if (format != expected) return null;
  if (image.planes.length != 1) return null;

  final plane = image.planes.first;
  return InputImage.fromBytes(
    bytes: plane.bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: plane.bytesPerRow,
    ),
  );
}

/// Lignes reconnues, du bas de l'image vers le haut : le code collector est
/// imprimé en pied de carte, c'est donc là qu'il faut chercher en premier.
List<String> linesFromBottom(RecognizedText recognized) {
  final lines = [
    for (final block in recognized.blocks)
      for (final line in block.lines) line,
  ];
  lines.sort((a, b) => b.boundingBox.bottom.compareTo(a.boundingBox.bottom));
  return [for (final line in lines) line.text];
}
