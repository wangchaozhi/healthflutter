import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart';
// 条件导入：仅在Web平台导入web_download
import '../utils/web_download_stub.dart' if (dart.library.html) '../utils/web_download.dart' as web_download;
import '../utils/native_download.dart' if (dart.library.html) '../utils/web_download_stub.dart' as native_download;

class DouyinParserScreen extends StatefulWidget {
  const DouyinParserScreen({super.key});

  @override
  State<DouyinParserScreen> createState() => _DouyinParserScreenState();
}

class _DouyinParserScreenState extends State<DouyinParserScreen> {
  final TextEditingController _inputController = TextEditingController();
  List<Map<String, dynamic>> _fileList = [];
  bool _isParsing = false;
  bool _isDownloading = false;
  bool _hasInput = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _clearInput() {
    _inputController.clear();
  }

  Future<void> _handleParsing() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入抖音分享链接')),
      );
      return;
    }

    setState(() {
      _isParsing = true;
    });

    final result = await ApiService.douyinParsing(text);

    setState(() {
      _isParsing = false;
    });

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('解析成功')),
      );
      // 刷新文件列表
      await _loadFileList();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? '解析失败')),
      );
    }
  }

  Future<void> _loadFileList() async {
    final result = await ApiService.getDouyinFileList();
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _fileList = List<Map<String, dynamic>>.from(result['list'] ?? []);
        }
      });
    }
  }

  Future<void> _handleDownload(String id, String path, String fileName) async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final token = await ApiService.getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先登录')),
          );
        }
        return;
      }
      
      // 构建下载URL
      final downloadUrl = await ApiService.getDownloadUrl(int.parse(id));
      
      if (kIsWeb) {
        // 在Web平台，直接使用fetch API下载，避免将整个文件加载到内存
        try {
          await web_download.downloadFileWebDirect(downloadUrl, token, fileName);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('开始下载: $fileName')),
            );
          }
        } catch (e) {
          debugPrint('Web下载失败: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('下载失败，请重试: $e')),
            );
          }
        }
      } else {
        // 在移动端和桌面端，使用native下载功能
        try {
          final filePath = await native_download.downloadFileNative(downloadUrl, token, fileName);
          if (mounted) {
            // 检查是否为视频文件和是否为移动端
            final isVideo = fileName.toLowerCase().endsWith('.mp4') ||
                fileName.toLowerCase().endsWith('.avi') ||
                fileName.toLowerCase().endsWith('.mov') ||
                fileName.toLowerCase().endsWith('.mkv') ||
                fileName.toLowerCase().endsWith('.flv') ||
                fileName.toLowerCase().endsWith('.wmv') ||
                fileName.toLowerCase().endsWith('.webm');
            
            // 检查是否为移动端（Android/iOS）
            final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  (isVideo && isMobile)
                    ? '下载成功！视频已保存到相册\n$fileName'
                    : '下载成功: $fileName\n路径: $filePath'
                ),
                action: SnackBarAction(
                  label: '打开目录',
                  onPressed: () async {
                    try {
                      await native_download.openDownloadDirectory(filePath);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('无法打开文件管理器，请手动访问: $filePath')),
                        );
                      }
                    }
                  },
                ),
                duration: const Duration(seconds: 6),
              ),
            );
          }
        } catch (e) {
          debugPrint('下载失败: $e');
          if (mounted) {
            String errorMessage = '下载失败: $e';
            // 如果是权限问题，提供更友好的提示
            if (e.toString().contains('权限') || e.toString().contains('permission')) {
              errorMessage = '下载失败: 需要存储权限才能下载到公共下载目录，请在设置中授予存储权限';
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFileList();
    _inputController.addListener(() {
      setState(() {
        _hasInput = _inputController.text.isNotEmpty;
      });
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('抖音解析工具'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth > 800 ? 800.0 : constraints.maxWidth;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 输入容器
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 输入框和清除按钮
                          Stack(
                            alignment: Alignment.centerRight,
                            children: [
                              TextField(
                                controller: _inputController,
                                decoration: const InputDecoration(
                                  labelText: '请输入抖音分享链接',
                                  border: OutlineInputBorder(),
                                  hintText: '粘贴抖音分享链接',
                                ),
                                maxLines: 3,
                              ),
                              if (_hasInput)
                                Positioned(
                                  right: 8,
                                  child: IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: _clearInput,
                                    iconSize: 20,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: (_isParsing || _isDownloading) ? null : _handleParsing,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isParsing
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('解析'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 文件列表
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _fileList.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Center(
                                child: Text(
                                  '暂无文件',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _fileList.length,
                              itemBuilder: (context, index) {
                                final file = _fileList[index];
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey.shade200,
                                        width: index < _fileList.length - 1 ? 1 : 0,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              file['file_name'] ?? '未知文件',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '大小: ${file['file_size_str'] ?? '未知'}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '时间: ${file['modified_time'] ?? '未知'}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      ElevatedButton(
                                        onPressed: (_isParsing || _isDownloading)
                                            ? null
                                            : () => _handleDownload(
                                                  file['id'].toString(),
                                                  file['path'] ?? '',
                                                  file['file_name'] ?? '未知文件',
                                                ),
                                        child: const Text('下载'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

