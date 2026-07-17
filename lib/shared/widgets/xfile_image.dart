import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Displays a picked XFile's image content identically across Web,
/// Android, and iOS. XFile.path is a loadable blob URL on Web but a local
/// file path on Android/iOS -- Image.network only works for the former.
/// Reading bytes once and using Image.memory sidesteps the platform
/// difference entirely instead of branching on kIsWeb.
class XFileImage extends StatelessWidget {
  const XFileImage({super.key, required this.file, this.fit = BoxFit.cover});

  final XFile file;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ColoredBox(
            color: Color(0xFFF2F2EF),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return Image.memory(snapshot.data!, fit: fit);
      },
    );
  }
}
