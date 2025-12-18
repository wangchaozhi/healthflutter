import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../utils/web_download.dart';

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
          await downloadFileWebDirect(downloadUrl, token, fileName);
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
        // 在移动端，使用http请求下载
        final response = await http.get(
          Uri.parse(downloadUrl),
          headers: {
            'Authorization': 'Bearer $token',
          },
        );
        
        if (mounted) {
          if (response.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('下载成功: $fileName')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('下载失败: ${response.statusCode}')),
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

