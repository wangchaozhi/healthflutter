// Stub for non-Web platforms
import 'package:flutter/material.dart';

/// Stub for WebDropZone on non-Web platforms
class WebDropZone extends StatelessWidget {
  final Function(List<dynamic> files) onFilesDropped;
  final Widget child;

  const WebDropZone({
    super.key,
    required this.onFilesDropped,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

