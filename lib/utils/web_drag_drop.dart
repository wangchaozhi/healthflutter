// Web platform drag and drop utilities
import 'dart:html' as html;
import 'package:flutter/material.dart';

/// Web端拖拽上传组件
/// 使用简化的方法，不依赖platformViewRegistry
class WebDropZone extends StatefulWidget {
  final Function(List<html.File> files) onFilesDropped;
  final Widget child;

  const WebDropZone({
    super.key,
    required this.onFilesDropped,
    required this.child,
  });

  @override
  State<WebDropZone> createState() => _WebDropZoneState();
}

class _WebDropZoneState extends State<WebDropZone> {
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _setupDragDropListeners();
  }

  void _setupDragDropListeners() {
    // 在window上设置拖放事件监听器
    html.window.addEventListener('dragenter', _handleDragEnter);
    html.window.addEventListener('dragover', _handleDragOver);
    html.window.addEventListener('dragleave', _handleDragLeave);
    html.window.addEventListener('drop', _handleDrop);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: _isDragging
            ? Border.all(color: Colors.blue, width: 2)
            : null,
      ),
      child: widget.child,
    );
  }

  void _handleDragEnter(html.Event e) {
    e.preventDefault();
    e.stopPropagation();
    if (!_isDragging) {
      setState(() {
        _isDragging = true;
      });
    }
  }

  void _handleDragOver(html.Event e) {
    e.preventDefault();
    e.stopPropagation();
  }

  void _handleDragLeave(html.Event e) {
    e.preventDefault();
    e.stopPropagation();
    // 简单重置拖拽状态
    setState(() {
      _isDragging = false;
    });
  }

  void _handleDrop(html.Event e) {
    e.preventDefault();
    e.stopPropagation();
    
    setState(() {
      _isDragging = false;
    });

    final dataTransfer = (e as html.MouseEvent).dataTransfer;
    final files = dataTransfer?.files;
    if (files != null && files.isNotEmpty) {
      final fileList = <html.File>[];
      for (var i = 0; i < files.length; i++) {
        fileList.add(files[i]);
      }
      if (fileList.isNotEmpty) {
        widget.onFilesDropped(fileList);
      }
    }
  }

  @override
  void dispose() {
    html.window.removeEventListener('dragenter', _handleDragEnter);
    html.window.removeEventListener('dragover', _handleDragOver);
    html.window.removeEventListener('dragleave', _handleDragLeave);
    html.window.removeEventListener('drop', _handleDrop);
    super.dispose();
  }
}
