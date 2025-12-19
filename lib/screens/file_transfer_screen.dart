import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:desktop_drop/desktop_drop.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../utils/debounce.dart';
import '../utils/platform_io.dart' if (dart.library.html) '../utils/platform_stub.dart' as platform;
import '../utils/file_upload_io.dart' if (dart.library.html) '../utils/file_upload_stub.dart' as file_upload;
import '../utils/web_drag_drop_stub.dart' if (dart.library.html) '../utils/web_drag_drop.dart';
import '../utils/web_file_upload_stub.dart' if (dart.library.html) '../utils/web_file_upload.dart' as web_upload;
import '../utils/web_download_stub.dart' if (dart.library.html) '../utils/web_download.dart' as web_download;
import '../utils/native_download.dart' if (dart.library.html) '../utils/web_download_stub.dart' as native_download;

class FileTransferScreen extends StatefulWidget {
  const FileTransferScreen({super.key});

  @override
  State<FileTransferScreen> createState() => _FileTransferScreenState();
}

class _FileTransferScreenState extends State<FileTransferScreen> {
  List<dynamic> _fileList = [];
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isDownloading = false;
  int? _downloadingFileId; // 记录正在下载的文件ID
  double _downloadProgress = 0.0; // 下载进度 0.0 - 1.0
  int _currentPage = 1;
  int _totalPages = 1;
  int _total = 0;
  final int _pageSize = 10;
  
  // 文本输入控制器（用于移动端Web手动粘贴）
  final TextEditingController _textController = TextEditingController();
  
  // 防抖
  final DebounceState _uploadDebounce = DebounceState();
  final DebounceState _deleteDebounce = DebounceState();
  final DebounceState _clipboardDebounce = DebounceState();

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // 加载文件列表
  Future<void> _loadFiles({int page = 1}) async {
    setState(() {
      _isLoading = true;
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

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/file/list?page=$page&page_size=$_pageSize'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          setState(() {
            _fileList = data['data']['list'] ?? [];
            _total = data['data']['total'] ?? 0;
            _currentPage = data['data']['page'] ?? 1;
            _totalPages = (_total / _pageSize).ceil();
            if (_totalPages == 0) _totalPages = 1;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message'] ?? '加载失败')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('加载失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Web端拖拽上传处理
  Future<void> _handleWebFileDrop(List<dynamic> files) async {
    if (files.isEmpty) return;
    
    for (var file in files) {
      await _uploadWebFile(file);
    }
  }

  // Web端上传文件
  Future<void> _uploadWebFile(dynamic file) async {
    if (!_uploadDebounce.canExecute) return;

    await _uploadDebounce.execute(
      action: () async {
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

          if (!kIsWeb) return;

          // 使用Web文件上传工具
          final result = await web_upload.uploadWebFile(
            file,
            token,
            ApiConfig.baseUrl,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['message'] ?? '操作完成')),
            );
            if (result['success'] == true) {
              _loadFiles(page: _currentPage);
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('上传失败: $e')),
            );
          }
        }
      },
      onStart: () {
        // 显示上传 loading
        if (mounted) {
          setState(() {
            _isUploading = true;
          });
        }
      },
      onEnd: () {
        // 隐藏上传 loading
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      },
    );
  }

  // 直接上传文件（用于桌面端拖拽上传）
  Future<void> _uploadFileDirectly(String filePath) async {
    if (!_uploadDebounce.canExecute) return;

    await _uploadDebounce.execute(
      action: () async {
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

          if (kIsWeb) {
            // Web平台不支持拖拽上传
            return;
          }

          // 使用文件上传工具（仅非Web平台）
          await file_upload.uploadFileFromDragPath(
            filePath,
            token,
            ApiConfig.baseUrl,
            (success, message) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
                if (success) {
                  _loadFiles(page: _currentPage);
                }
              }
            },
            (progress) {
              // 不再更新上传进度
            },
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('上传失败: $e')),
            );
          }
        }
      },
      onStart: () {
        // 显示上传 loading
        if (mounted) {
          setState(() {
            _isUploading = true;
          });
        }
      },
      onEnd: () {
        // 隐藏上传 loading
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      },
    );
  }

  // 上传文件（通过文件选择器）
  Future<void> _uploadFile() async {
    if (!_uploadDebounce.canExecute) return;

    await _uploadDebounce.execute(
      action: () async {
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

          // 打开文件选择器（此时不显示loading）
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.any,
            allowMultiple: false,
          );

          // 用户选择了文件后，才显示loading
          if (result != null) {
            debugPrint('用户选择了文件，显示loading');
            if (mounted) {
              setState(() {
                _isUploading = true;
              });
            }
            if (kIsWeb) {
              // Web平台使用不同的上传方式
              if (result.files.single.bytes != null) {
                // Web平台上传逻辑
                final token = await ApiService.getToken();
                if (token == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请先登录')),
                    );
                  }
                  return;
                }

                // 创建multipart request
                var request = http.MultipartRequest(
                  'POST',
                  Uri.parse('${ApiConfig.baseUrl}/file/upload'),
                );
                request.headers['Authorization'] = 'Bearer $token';
                request.files.add(
                  http.MultipartFile.fromBytes(
                    'file',
                    result.files.single.bytes!,
                    filename: result.files.single.name,
                  ),
                );

                // 发送请求
                var streamedResponse = await request.send();
                var response = await http.Response.fromStream(streamedResponse);

                debugPrint('Web上传响应状态码: ${response.statusCode}');
                if (response.statusCode == 200) {
                  final data = jsonDecode(utf8.decode(response.bodyBytes));
                  debugPrint('Web上传成功: $data');
                  if (data['success'] == true) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('上传成功')),
                      );
                    }
                    await _loadFiles(page: _currentPage);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(data['message'] ?? '上传失败')),
                      );
                    }
                  }
                } else {
                  debugPrint('Web上传失败');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('上传失败: ${response.statusCode}')),
                    );
                  }
                }
              }
            } else {
              // 非Web平台
              if (result.files.single.path != null) {
                final token = await ApiService.getToken();
                if (token != null) {
                  await file_upload.uploadFileFromPlatformFile(
                    result.files.single,
                    token,
                    ApiConfig.baseUrl,
                    (success, message) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(message)),
                        );
                        if (success) {
                          _loadFiles(page: _currentPage);
                        }
                      }
                    },
                    (progress) {
                      // 不再更新上传进度
                    },
                  );
                }
              }
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('上传失败: $e')),
            );
          }
        } finally {
          // 无论成功还是失败，都关闭loading
          debugPrint('上传流程结束，关闭loading');
          if (mounted) {
            setState(() {
              _isUploading = false;
            });
            debugPrint('loading已关闭: _isUploading = false');
          } else {
            debugPrint('Widget已卸载，无法关闭loading');
          }
        }
      },
    );
  }

  // 保存粘贴板内容（桌面端自动获取）
  Future<void> _saveClipboard() async {
    if (!_clipboardDebounce.canExecute) return;

    await _clipboardDebounce.execute(
      action: () async {
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

          // 获取粘贴板内容
          final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
          if (clipboardData == null || clipboardData.text == null || clipboardData.text!.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('粘贴板为空')),
              );
            }
            return;
          }

          await _saveTextContent(clipboardData.text!);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('保存失败: $e')),
            );
          }
        }
      },
    );
  }

  // 保存文本内容（共用方法）
  Future<void> _saveTextContent(String content) async {
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

      if (content.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('内容为空')),
          );
        }
        return;
      }

      // 发送请求
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/file/clipboard'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'content': content,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('保存成功')),
            );
            // 清空输入框
            _textController.clear();
          }
          _loadFiles(page: _currentPage);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message'] ?? '保存失败')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  // 删除文件
  Future<void> _deleteFile(int fileId) async {
    if (!_deleteDebounce.canExecute) return;

    await _deleteDebounce.execute(
      action: () async {
        try {
          final token = await ApiService.getToken();
          if (token == null) {
            return;
          }

          final response = await http.delete(
            Uri.parse('${ApiConfig.baseUrl}/file/delete?id=$fileId'),
            headers: {
              'Authorization': 'Bearer $token',
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            if (data['success'] == true) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('删除成功')),
                );
              }
              _loadFiles(page: _currentPage);
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('删除失败: $e')),
            );
          }
        }
      },
    );
  }

  // 下载文件
  Future<void> _downloadFile(int fileId, String fileName) async {
    // 设置下载状态
    setState(() {
      _isDownloading = true;
      _downloadingFileId = fileId;
      _downloadProgress = 0.0;
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

      // 获取下载URL
      final downloadUrl = '${ApiConfig.baseUrl}/file/download?id=$fileId';

      if (kIsWeb) {
        // Web平台直接下载（带进度）
        try {
          await web_download.downloadFileWebDirectWithProgress(
            downloadUrl, 
            token, 
            fileName,
            (progress) {
              if (mounted) {
                setState(() {
                  _downloadProgress = progress;
                });
              }
            },
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('下载成功: $fileName')),
            );
          }
        } catch (e) {
          debugPrint('Web端下载失败: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('下载失败: $e')),
            );
          }
        }
      } else {
        // 移动端和桌面端下载（带进度）
        try {
          final filePath = await native_download.downloadFileNativeWithProgress(
            downloadUrl, 
            token, 
            fileName,
            (progress) {
              if (mounted) {
                setState(() {
                  _downloadProgress = progress;
                });
              }
            },
          );
          if (mounted) {
            // 判断是否是移动端
            final isMobile = Platform.isAndroid || Platform.isIOS;
            
            if (isMobile) {
              // 移动端：简单提示，不显示路径和打开目录按钮
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('下载成功: $fileName'),
                  duration: const Duration(seconds: 3),
                ),
              );
            } else {
              // 桌面端：显示路径和打开目录按钮
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('下载成功: $fileName\n路径: $filePath'),
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
          }
        } catch (e) {
          debugPrint('下载失败: $e');
          if (mounted) {
            String errorMessage = '下载失败: $e';
            if (e.toString().contains('Permission denied')) {
              errorMessage = '下载失败: 需要存储权限才能下载文件，请在设置中授予存储权限';
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage)),
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
      // 清除下载状态
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadingFileId = null;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('文件传输'),
            centerTitle: true,
          ),
          body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth > 1200 ? 1200.0 : constraints.maxWidth;
          final isMobileScreen = constraints.maxWidth < 600; // 判断是否为移动端屏幕尺寸
          
          return Center(
            child: SizedBox(
              width: maxWidth,
              child: Column(
                children: [
                  // 操作按钮区域和拖拽上传区域
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // 拖拽上传区域（移动端屏幕隐藏）
                        if (!isMobileScreen && kIsWeb)
                          // Web端拖拽上传
                          WebDropZone(
                            onFilesDropped: (files) {
                              _handleWebFileDrop(files);
                            },
                            child: Container(
                              width: double.infinity,
                              height: 120,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey,
                                  width: 2,
                                  style: BorderStyle.solid,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey.withOpacity(0.05),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cloud_upload,
                                      size: 48,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '拖拽文件到此处上传',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '或点击下方按钮选择文件',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else if (!isMobileScreen)
                          // 桌面端拖拽上传（移动端屏幕隐藏）
                          Builder(
                            builder: (context) {
                              // 在非Web平台检查是否为桌面端
                              if (platform.isMobile()) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                children: [
                                  DropTarget(
                                    onDragDone: (detail) async {
                                      // 处理拖拽的文件
                                      for (var file in detail.files) {
                                        await _uploadFileDirectly(file.path);
                                      }
                                    },
                                    onDragEntered: (detail) {
                                      setState(() {
                                        // 可以添加拖拽进入时的视觉反馈
                                      });
                                    },
                                    onDragExited: (detail) {
                                      setState(() {
                                        // 可以添加拖拽离开时的视觉反馈
                                      });
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey,
                                          width: 2,
                                          style: BorderStyle.solid,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.grey.withOpacity(0.05),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.cloud_upload,
                                              size: 48,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '拖拽文件到此处上传',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '或点击下方按钮选择文件',
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              );
                            },
                          ),
                            ],
                          ),
                        ),
                      // 按钮区域
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _uploadDebounce.canExecute ? _uploadFile : null,
                                    icon: const Icon(Icons.upload_file),
                                    label: const Text('上传文件'),
                                  ),
                                ),
                                // 桌面端：保存粘贴板按钮（自动获取剪贴板）
                                if (!(kIsWeb && isMobileScreen)) ...[
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _clipboardDebounce.canExecute ? _saveClipboard : null,
                                      icon: _clipboardDebounce.canExecute
                                          ? const Icon(Icons.content_paste)
                                          : const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                      label: const Text('保存粘贴板'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            // 移动端Web：文本输入框
                            if (kIsWeb && isMobileScreen) ...[
                              const SizedBox(height: 16),
                              TextField(
                                controller: _textController,
                                maxLines: 5,
                                decoration: InputDecoration(
                                  hintText: '在此粘贴文本内容...',
                                  border: const OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.grey.withValues(alpha: 0.1),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _clipboardDebounce.canExecute 
                                    ? () => _saveTextContent(_textController.text)
                                    : null,
                                  icon: _clipboardDebounce.canExecute
                                      ? const Icon(Icons.save)
                                      : const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                  label: const Text('保存文本'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  // 文件列表
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _fileList.isEmpty
                            ? const Center(child: Text('暂无文件'))
                            : ListView.builder(
                                itemCount: _fileList.length,
                                itemBuilder: (context, index) {
                                  final file = _fileList[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: ListTile(
                                      leading: const Icon(Icons.insert_drive_file),
                                      title: Text(file['file_name'] ?? ''),
                                      subtitle: Text(
                                        '${file['file_size_str'] ?? ''} • ${file['created_at'] ?? ''}',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // 下载按钮/进度
                                          _isDownloading && _downloadingFileId == file['id']
                                            ? SizedBox(
                                                width: 80,
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    LinearProgressIndicator(
                                                      value: _downloadProgress,
                                                      backgroundColor: Colors.grey[300],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                                                      style: const TextStyle(fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : IconButton(
                                                icon: const Icon(Icons.download),
                                                onPressed: _isDownloading 
                                                  ? null 
                                                  : () => _downloadFile(
                                                      file['id'],
                                                      file['file_name'],
                                                    ),
                                              ),
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            onPressed: _deleteDebounce.canExecute
                                                ? () => _deleteFile(file['id'])
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                  // 分页控件
                  if (_totalPages > 1)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _currentPage > 1
                                ? () => _loadFiles(page: _currentPage - 1)
                                : null,
                          ),
                          Text('第 $_currentPage / $_totalPages 页 (共 $_total 个文件)'),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _currentPage < _totalPages
                                ? () => _loadFiles(page: _currentPage + 1)
                                : null,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
        ),
        // 全局上传loading遮罩
        if (_isUploading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        '正在上传...',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

