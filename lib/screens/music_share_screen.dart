import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../utils/debounce.dart';

class MusicShareScreen extends StatefulWidget {
  const MusicShareScreen({super.key});

  @override
  State<MusicShareScreen> createState() => _MusicShareScreenState();
}

class _MusicShareScreenState extends State<MusicShareScreen> {
  List<dynamic> _shareList = [];
  bool _isLoading = false;
  
  // 防抖
  final DebounceState _deleteDebounce = DebounceState();

  @override
  void initState() {
    super.initState();
    _loadShares();
  }

  // 加载分享列表
  Future<void> _loadShares() async {
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
        Uri.parse('${ApiConfig.baseUrl}/music/share/list'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          setState(() {
            _shareList = data['list'] ?? [];
          });
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

  // 删除分享
  Future<void> _deleteShare(int shareId) async {
    if (!_deleteDebounce.canExecute) return;

    await _deleteDebounce.execute(
      action: () async {
        try {
          final token = await ApiService.getToken();
          if (token == null) {
            return;
          }

          final response = await http.delete(
            Uri.parse('${ApiConfig.baseUrl}/music/share/delete?id=$shareId'),
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
              await _loadShares();
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

  // 复制分享链接
  void _copyShareLink(String shareToken) {
    // 构建Web播放页面的URL（后端提供的HTML页面）
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
    final shareUrl = '$baseUrl/share/$shareToken';
    
    Clipboard.setData(ClipboardData(text: shareUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('分享链接已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的分享'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _shareList.isEmpty
              ? const Center(
                  child: Text(
                    '暂无分享\n在音乐播放器中点击分享按钮创建分享',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadShares,
                  child: ListView.builder(
                    itemCount: _shareList.length,
                    itemBuilder: (context, index) {
                      final share = _shareList[index];
                      final shareToken = share['share_token'] ?? '';
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.music_note,
                            size: 40,
                            color: Colors.blue,
                          ),
                          title: Text(
                            share['title'] ?? '未知标题',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(share['artist'] ?? '未知艺术家'),
                              const SizedBox(height: 4),
                              Text(
                                '浏览次数: ${share['view_count'] ?? 0}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                '创建时间: ${share['created_at']?.substring(0, 10) ?? ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy, color: Colors.blue),
                                onPressed: () => _copyShareLink(shareToken),
                                tooltip: '复制链接',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('确认删除'),
                                      content: const Text('删除后，分享链接将失效，他人将无法访问'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('取消'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _deleteShare(share['id']);
                                          },
                                          child: const Text(
                                            '删除',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                tooltip: '删除分享',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

