import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

Future<Uint8List?> pickImageBytes() async {
  final completer = Completer<Uint8List?>();
  try {
    final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'image/*';
    uploadInput.click();

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        reader.onLoadEnd.listen((e) {
          final result = reader.result;
          if (result is Uint8List) {
            completer.complete(result);
          } else if (result is List<int>) {
            completer.complete(Uint8List.fromList(result));
          } else {
            completer.complete(null);
          }
        });
      } else {
        completer.complete(null);
      }
    });

    html.window.onFocus.first.then((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });
    });
  } catch (e) {
    debugPrint('Web image pick error: $e');
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  }
  return completer.future;
}
