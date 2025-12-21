import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';

/// 歌词管理对话框
class LyricsManageDialog extends StatefulWidget {
  final int musicId;
  final String musicTitle;
  final String musicArtist;
  final Function()? onLyricsChanged; // 歌词变化回调

  const LyricsManageDialog({
    super.key,
    required this.musicId,
    required this.musicTitle,
    required this.musicArtist,
    this.onLyricsChanged,
  });

  @override
  State<LyricsManageDialog> createState() => _LyricsManageDialogState();
}

class _LyricsManageDialogState extends State<LyricsManageDialog> {
  bool _isLoading = false;
  bool _isUploading = false;
  bool _hasCurrentLyrics = false; // 当前歌曲是否有绑定的歌词
  List<dynamic> _lyricsList = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkCurrentLyrics();
    _searchLyrics('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 检查当前歌曲是否有绑定的歌词
  Future<void> _checkCurrentLyrics() async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/lyrics/get?music_id=${widget.musicId}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _hasCurrentLyrics = data['success'] == true && data['lyrics'] != null;
          });
        }
      }
    } catch (e) {
      debugPrint('检查歌词绑定状态失败: $e');
    }
  }

  /// 搜索歌词
  Future<void> _searchLyrics(String keyword) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return;
      }

      String url = '${ApiConfig.baseUrl}/lyrics/search';
      if (keyword.isNotEmpty) {
        url += '?keyword=${Uri.encodeComponent(keyword)}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          setState(() {
            _lyricsList = data['list'] ?? [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
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

  /// 上传歌词文件
  Future<void> _uploadLyrics() async {
    // 先打开文件选择器，不显示loading（参考文件传输页面的实现）
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['lrc', 'txt'],
        allowMultiple: false,
        withData: true, // 确保读取文件数据（Web和移动端都支持）
        withReadStream: false, // 不使用流，直接读取数据
      );

      // 用户选择了文件后，才显示loading
      if (result == null || result.files.isEmpty) {
        return; // 用户取消选择，直接返回
      }
      
      // 用户选择了文件，开始显示loading
      if (mounted) {
        setState(() {
          _isUploading = true;
        });
      }

      final pickedFile = result.files.single;
      final token = await ApiService.getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未登录，请先登录')),
          );
          setState(() {
            _isUploading = false;
          });
        }
        return;
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/lyrics/upload'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      
      // 添加文件 - 优先使用 bytes（Web 和移动端都支持）
      http.MultipartFile multipartFile;
      
      if (pickedFile.bytes != null) {
        // 使用 bytes（Web 和移动端都支持）
        multipartFile = http.MultipartFile.fromBytes(
          'file',
          pickedFile.bytes!,
          filename: pickedFile.name,
        );
      } else if (pickedFile.path != null) {
        // 移动端：使用路径读取文件
        try {
          multipartFile = await http.MultipartFile.fromPath(
            'file',
            pickedFile.path!,
            filename: pickedFile.name,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('读取文件失败: $e')),
            );
            setState(() {
              _isUploading = false;
            });
          }
          return;
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法读取文件，请重试')),
          );
          setState(() {
            _isUploading = false;
          });
        }
        return;
      }
      
      request.files.add(multipartFile);

      // 添加元数据
      request.fields['title'] = widget.musicTitle;
      request.fields['artist'] = widget.musicArtist;
      request.fields['music_id'] = widget.musicId.toString();

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('上传并绑定成功')),
            );
            // 通知歌词已变化
            widget.onLyricsChanged?.call();
            Navigator.pop(context);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message'] ?? '上传失败')),
            );
          }
        }
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('上传失败: ${response.statusCode}\n$errorBody')),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('上传歌词文件错误: $e');
      debugPrint('堆栈跟踪: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('上传失败: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  /// 绑定歌词
  Future<void> _bindLyrics(int lyricsId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return;
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/lyrics/bind'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'music_id': widget.musicId,
          'lyrics_id': lyricsId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('绑定成功')),
            );
            // 通知歌词已变化
            widget.onLyricsChanged?.call();
            Navigator.pop(context);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message'] ?? '绑定失败')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('绑定失败: $e')),
        );
      }
    }
  }

  /// 取消绑定歌词
  Future<void> _unbindLyrics() async {
    // 确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认取消绑定'),
        content: const Text('确定要取消当前歌曲的歌词绑定吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return;
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/lyrics/unbind?music_id=${widget.musicId}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('取消绑定成功')),
            );
            setState(() {
              _hasCurrentLyrics = false;
            });
            // 通知歌词已变化
            widget.onLyricsChanged?.call();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message'] ?? '取消绑定失败')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('取消绑定失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '选择歌词',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.musicTitle} - ${widget.musicArtist}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 搜索框
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜索歌词...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (value) => _searchLyrics(value),
                  ),
                ),
                const SizedBox(width: 8),
                // 取消绑定按钮（手机端显示更小的图标按钮）
                if (_hasCurrentLyrics)
                  IconButton(
                    onPressed: _unbindLyrics,
                    icon: const Icon(Icons.link_off, size: 20),
                    tooltip: '取消绑定',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                if (_hasCurrentLyrics) const SizedBox(width: 8),
                // 上传按钮
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _uploadLyrics,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file, size: 18),
                  label: const Text('上传', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(60, 36),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 歌词列表
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _lyricsList.isEmpty
                      ? const Center(
                          child: Text(
                            '暂无歌词\n请上传或搜索',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _lyricsList.length,
                          itemBuilder: (context, index) {
                            final lyrics = _lyricsList[index];
                            final isAlreadyBound = lyrics['music_id'] != null &&
                                lyrics['music_id'] == widget.musicId;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.lyrics,
                                  color: Colors.blue,
                                ),
                                title: Text(lyrics['title'] ?? '未知'),
                                subtitle: Text(lyrics['artist'] ?? '未知艺术家'),
                                trailing: isAlreadyBound
                                    ? const Chip(
                                        label: Text('已绑定'),
                                        backgroundColor: Colors.green,
                                        labelStyle: TextStyle(color: Colors.white),
                                      )
                                    : ElevatedButton(
                                        onPressed: () => _bindLyrics(lyrics['id']),
                                        child: const Text('绑定'),
                                      ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
