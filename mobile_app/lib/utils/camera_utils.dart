import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/foundation.dart';

class CameraUtils {
  static InputImage inputImageFromCameraImage(CameraImage image,
      CameraDescription camera, InputImageRotation rotation) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;

    // Since we're using bgra8888 in iOS and yuv420 in Android mostly
    // We need to handle planes

    if (format == InputImageFormat.nv21 ||
        format == InputImageFormat.yuv420 ||
        format == InputImageFormat.yv12) {
      // Android usually
      return _inputImageFromYuv420(image, camera, rotation, format);
    } else if (format == InputImageFormat.bgra8888) {
      // iOS usually
      return _inputImageFromBgra8888(image, camera, rotation, format);
    }

    // Fallback or other formats handling if needed
    // For simplicity, using the bytes directly
    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final size = Size(image.width.toDouble(), image.height.toDouble());

    final inputImageMetadata = InputImageMetadata(
      size: size,
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
  }

  static InputImage _inputImageFromYuv420(
      CameraImage image,
      CameraDescription camera,
      InputImageRotation rotation,
      InputImageFormat format) {
    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final size = Size(image.width.toDouble(), image.height.toDouble());

    final inputImageMetadata = InputImageMetadata(
      size: size,
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
  }

  static InputImage _inputImageFromBgra8888(
      CameraImage image,
      CameraDescription camera,
      InputImageRotation rotation,
      InputImageFormat format) {
    final plane = image.planes[0];

    final size = Size(image.width.toDouble(), image.height.toDouble());

    final inputImageMetadata = InputImageMetadata(
      size: size,
      rotation: rotation,
      format: format,
      bytesPerRow: plane.bytesPerRow,
    );

    return InputImage.fromBytes(
        bytes: plane.bytes, metadata: inputImageMetadata);
  }
}
