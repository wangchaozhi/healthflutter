import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../config/api_config.dart';
import '../services/token_storage.dart';
import '../services/music_player_service.dart';
import '../services/cache_service.dart';
import '../utils/debounce.dart';
import '../utils/platform_utils.dart';
import '../widgets/lyrics_manage_dialog.dart';
import 'lyrics_detail_screen.dart';
import 'cache_settings_screen.dart';

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  List<dynamic> _musicList = [];
  bool _isLoading = false;
  bool _isUploading = false;
  int _currentPage = 1;
  int _totalPages = 1;
  int _total = 0;
  final int _pageSize = 20;

  // 全局音乐播放器服务
  final MusicPlayerService _playerService = MusicPlayerService();
  
  // 缓存服务
  final CacheService _cacheService = CacheService();

  // 防抖
  final DebounceState _uploadDebounce = DebounceState();
  final DebounceState _deleteDebounce = DebounceState();
  
  // 搜索
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';

  // 歌词相关
  String? _currentLyrics; // 当前歌曲的歌词内容

  @override
  void initState() {
    super.initState();
    _loadMusicList();
    // 监听播放器状态变化
    _playerService.addListener(_onPlayerStateChanged);
    
    // 如果有正在播放的歌曲，加载其歌词
    if (_playerService.currentPlayingId != null) {
      _loadLyrics(_playerService.currentPlayingId!);
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _playerService.removeListener(_onPlayerStateChanged);
    // 注意：不要 dispose 全局播放器服务
    super.dispose();
  }
  
  // 播放器状态变化回调
  void _onPlayerStateChanged() {
    if (mounted) {
      setState(() {
        // 触发UI更新
      });
    }
  }
  
  // 获取播放模式图标
  IconData _getPlayModeIcon() {
    switch (_playerService.playMode) {
      case PlayMode.sequence:
        return Icons.repeat;
      case PlayMode.shuffle:
        return Icons.shuffle;
      case PlayMode.repeat:
        return Icons.repeat_one;
    }
  }
  
  // 获取播放模式名称
  String _getPlayModeName() {
    switch (_playerService.playMode) {
      case PlayMode.sequence:
        return '顺序播放';
      case PlayMode.shuffle:
        return '随机播放';
      case PlayMode.repeat:
        return '单曲循环';
    }
  }

  // 加载音乐列表
  Future<void> _loadMusicList({int page = 1, String? keyword}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        return;
      }

      // 构建 URL，包含搜索关键词
      String url = '${ApiConfig.baseUrl}/music/list?page=$page&pageSize=$_pageSize';
      if (keyword != null && keyword.isNotEmpty) {
        url += '&keyword=${Uri.encodeComponent(keyword)}';
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
            _musicList = data['list'] ?? [];
            _currentPage = data['currentPage'] ?? 1;
            _totalPages = data['totalPages'] ?? 1;
            _total = data['total'] ?? 0;
          });
          
          // 更新播放器服务的播放列表
          _playerService.setPlaylist(
            _musicList.map((m) => m as Map<String, dynamic>).toList(),
            onPlayNext: _playNext,
            onPlayPrevious: _playPrevious,
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

  // 执行搜索
  void _performSearch() {
    setState(() {
      _searchKeyword = _searchController.text.trim();
      _currentPage = 1; // 重置到第一页
    });
    _loadMusicList(page: 1, keyword: _searchKeyword);
  }
  
  // 清除搜索
  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchKeyword = '';
      _currentPage = 1;
    });
    _loadMusicList(page: 1);
  }

  // 上传音乐
  Future<void> _uploadMusic() async {
    if (!_uploadDebounce.canExecute) return;

    await _uploadDebounce.execute(
      action: () async {
        setState(() {
          _isUploading = true;
        });

        try {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.audio,
            allowMultiple: false,
          );

          if (result != null) {
            final token = await TokenStorage.getToken();
            if (token == null) {
              return;
            }

            if (kIsWeb) {
              // Web端上传
              if (result.files.single.bytes != null) {
                var request = http.MultipartRequest(
                  'POST',
                  Uri.parse('${ApiConfig.baseUrl}/music/upload'),
                );
                request.headers['Authorization'] = 'Bearer $token';
                request.files.add(
                  http.MultipartFile.fromBytes(
                    'file',
                    result.files.single.bytes!,
                    filename: result.files.single.name,
                  ),
                );

                var streamedResponse = await request.send();
                var response = await http.Response.fromStream(streamedResponse);

                if (response.statusCode == 200) {
                  final data = jsonDecode(utf8.decode(response.bodyBytes));
                  if (data['success'] == true) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('上传成功')),
                      );
                    }
                    await _loadMusicList(page: _currentPage, keyword: _searchKeyword);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(data['message'] ?? '上传失败')),
                      );
                    }
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('上传失败: ${response.statusCode}')),
                    );
                  }
                }
              }
            } else {
              // 移动端和桌面端上传
              if (result.files.single.path != null) {
                var request = http.MultipartRequest(
                  'POST',
                  Uri.parse('${ApiConfig.baseUrl}/music/upload'),
                );
                request.headers['Authorization'] = 'Bearer $token';
                request.files.add(
                  await http.MultipartFile.fromPath('file', result.files.single.path!),
                );

                var streamedResponse = await request.send();
                var response = await http.Response.fromStream(streamedResponse);

                if (response.statusCode == 200) {
                  final data = jsonDecode(utf8.decode(response.bodyBytes));
                  if (data['success'] == true) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('上传成功')),
                      );
                    }
                    await _loadMusicList(page: _currentPage, keyword: _searchKeyword);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(data['message'] ?? '上传失败')),
                      );
                    }
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('上传失败: ${response.statusCode}')),
                    );
                  }
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
          if (mounted) {
            setState(() {
              _isUploading = false;
            });
          }
        }
      },
    );
  }

  // 分享音乐
  Future<void> _shareMusic(int musicId) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先登录')),
          );
        }
        return;
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/music/share/create?music_id=$musicId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          // 使用后端返回的完整分享URL
          final shareUrl = data['share_url'];
          
          if (mounted) {
            // 复制链接到剪贴板
            Clipboard.setData(ClipboardData(text: shareUrl));
            
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('分享成功'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('分享链接已复制到剪贴板！'),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        shareUrl,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '提示：访问者无需登录即可播放',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/music_shares');
                    },
                    child: const Text('管理分享'),
                  ),
                ],
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message'] ?? '分享失败')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }

  // 删除音乐（添加确认对话框）
  Future<void> _deleteMusic(int musicId) async {
    if (!_deleteDebounce.canExecute) return;

    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这首音乐吗？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _deleteDebounce.execute(
      action: () async {
        try {
          final token = await TokenStorage.getToken();
          if (token == null) {
            return;
          }

          final response = await http.delete(
            Uri.parse('${ApiConfig.baseUrl}/music/delete?id=$musicId'),
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
              
              // 如果删除的是正在播放的音乐，停止播放
              if (_playerService.currentPlayingId == musicId) {
                await _playerService.stop();
              }
              
              await _loadMusicList(page: _currentPage);
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(data['message'] ?? '删除失败')),
                );
              }
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('删除失败: ${response.statusCode}')),
              );
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

  // 播放音乐
  Future<void> _playMusic(int musicId, {bool forceReplay = false}) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        debugPrint('Token为空，无法播放');
        return;
      }
      
      // 构建流式传输URL（通过URL参数传递token）
      final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
      final streamUrl = '$baseUrl/api/music/stream?id=$musicId&token=$token';
      
      // 获取音乐信息
      final music = _musicList.firstWhere(
        (m) => m['id'] == musicId,
        orElse: () => {'title': '未知', 'artist': '未知艺术家'},
      );
      
      // 检查是否有缓存（仅非Web平台）
      String finalStreamUrl = streamUrl;
      if (!kIsWeb) {
        final cachedPath = await _cacheService.getCachedMusicPath(musicId);
        if (cachedPath != null) {
          finalStreamUrl = cachedPath;
          debugPrint('📦 使用缓存音乐: $cachedPath');
        } else {
          debugPrint('📦 音乐未缓存，后台下载中...');
          // 异步缓存音乐文件（不阻塞播放）
          _cacheService.cacheMusic(musicId, streamUrl).then((path) {
            if (path != null) {
              debugPrint('✅ 音乐缓存完成: $path');
            }
          });
        }
      }
      
      // 使用全局播放器服务播放
      await _playerService.playMusic(
        musicId: musicId,
        streamUrl: finalStreamUrl,
        title: music['title'] ?? '未知',
        artist: music['artist'] ?? '未知艺术家',
        forceReplay: forceReplay,
      );
      
      // 加载歌词
      await _loadLyrics(musicId);
    } catch (e) {
      debugPrint('播放失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
      }
    }
  }
  
  // 播放/暂停
  Future<void> _togglePlayPause() async {
    if (_playerService.isPlaying) {
      await _playerService.pause();
    } else {
      await _playerService.resume();
    }
  }
  
  // 拖动进度条
  Future<void> _seek(double value) async {
    await _playerService.seek(value);
  }
  
  // 上一首
  Future<void> _playPrevious() async {
    if (_playerService.currentPlayingId == null || _musicList.isEmpty) return;
    
    final currentIndex = _musicList.indexWhere((m) => m['id'] == _playerService.currentPlayingId);
    
    // 根据播放模式处理
    switch (_playerService.playMode) {
      case PlayMode.sequence:
        // 顺序播放：如果是第一首，循环到最后一首
        if (currentIndex > 0) {
          await _playMusic(_musicList[currentIndex - 1]['id']);
        } else {
          // 循环到最后一首
          debugPrint('🎵 循环到最后一首');
          await _playMusic(_musicList[_musicList.length - 1]['id'], forceReplay: _musicList.length == 1);
        }
        break;
      case PlayMode.shuffle:
        // 随机播放：随机选择一首
        final random = Random();
        int nextIndex;
        if (_musicList.length == 1) {
          nextIndex = 0;
        } else {
          do {
            nextIndex = random.nextInt(_musicList.length);
          } while (nextIndex == currentIndex);
        }
        await _playMusic(_musicList[nextIndex]['id'], forceReplay: _musicList.length == 1);
        break;
      case PlayMode.repeat:
        // 单曲循环：播放上一首
        if (currentIndex > 0) {
          await _playMusic(_musicList[currentIndex - 1]['id']);
        } else {
          // 循环到最后一首
          await _playMusic(_musicList[_musicList.length - 1]['id'], forceReplay: _musicList.length == 1);
        }
        break;
    }
  }
  
  // 下一首
  Future<void> _playNext() async {
    if (_playerService.currentPlayingId == null || _musicList.isEmpty) return;
    
    final currentIndex = _musicList.indexWhere((m) => m['id'] == _playerService.currentPlayingId);
    
    // 根据播放模式选择下一首
    switch (_playerService.playMode) {
      case PlayMode.sequence:
        // 顺序播放：如果是最后一首，循环到第一首
        if (currentIndex < _musicList.length - 1) {
          await _playMusic(_musicList[currentIndex + 1]['id']);
        } else {
          // 循环到第一首
          debugPrint('🎵 循环到第一首');
          await _playMusic(_musicList[0]['id'], forceReplay: _musicList.length == 1);
        }
        break;
      case PlayMode.shuffle:
        // 随机播放
        final random = Random();
        int nextIndex;
        if (_musicList.length == 1) {
          nextIndex = 0;
        } else {
          do {
            nextIndex = random.nextInt(_musicList.length);
          } while (nextIndex == currentIndex);
        }
        await _playMusic(_musicList[nextIndex]['id'], forceReplay: _musicList.length == 1);
        break;
      case PlayMode.repeat:
        // 单曲循环（这里是手动点击下一首，所以还是播放下一首）
        if (currentIndex < _musicList.length - 1) {
          await _playMusic(_musicList[currentIndex + 1]['id']);
        } else {
          // 循环到第一首
          await _playMusic(_musicList[0]['id'], forceReplay: _musicList.length == 1);
        }
        break;
    }
  }

  // 加载歌词
  Future<void> _loadLyrics(int musicId) async {
    try {
      // 先从缓存读取
      final cachedLyrics = await _cacheService.getCachedLyrics(musicId);
      if (cachedLyrics != null) {
        debugPrint('📦 从缓存加载歌词: $musicId');
        setState(() {
          _currentLyrics = cachedLyrics;
        });
        return;
      }

      // 缓存不存在，从服务器获取
      debugPrint('🌐 从服务器加载歌词: $musicId');
      final token = await TokenStorage.getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/lyrics/get?music_id=$musicId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['lyrics'] != null) {
          final lyricsContent = data['lyrics']['content'];
          
          // 保存到缓存
          await _cacheService.cacheLyrics(musicId, lyricsContent);
          
          setState(() {
            _currentLyrics = lyricsContent;
          });
        } else {
          setState(() {
            _currentLyrics = null;
          });
        }
      }
    } catch (e) {
      debugPrint('加载歌词失败: $e');
      setState(() {
        _currentLyrics = null;
      });
    }
  }

  // 显示歌词管理对话框
  void _showLyricsManageDialog() {
    if (_playerService.currentPlayingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先播放歌曲')),
      );
      return;
    }

    final music = _musicList.firstWhere(
      (m) => m['id'] == _playerService.currentPlayingId,
      orElse: () => {'title': '未知', 'artist': '未知艺术家'},
    );

    showDialog(
      context: context,
      builder: (context) => LyricsManageDialog(
        musicId: _playerService.currentPlayingId!,
        musicTitle: music['title'] ?? '未知',
        musicArtist: music['artist'] ?? '未知艺术家',
        onLyricsChanged: () {
          // 重新加载歌词
          _loadLyrics(_playerService.currentPlayingId!);
        },
      ),
    );
  }

  // 打开歌词特写页面
  void _openLyricsDetailScreen() {
    if (_playerService.currentPlayingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先播放歌曲')),
      );
      return;
    }

    final music = _musicList.firstWhere(
      (m) => m['id'] == _playerService.currentPlayingId,
      orElse: () => {'title': '未知', 'artist': '未知艺术家'},
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LyricsDetailScreen(
          musicId: _playerService.currentPlayingId!,
          musicTitle: music['title'] ?? '未知',
          musicArtist: music['artist'] ?? '未知艺术家',
          lyricsContent: _currentLyrics,
          onLyricsChanged: () {
            // 重新加载歌词
            _loadLyrics(_playerService.currentPlayingId!);
          },
          onPlayNext: _playNext,
          onPlayPrevious: _playPrevious,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 键盘快捷键映射（所有平台都支持）
    final Map<LogicalKeySet, Intent> shortcuts = {
      LogicalKeySet(LogicalKeyboardKey.space): const _PlayPauseIntent(),
      LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _PreviousIntent(),
      LogicalKeySet(LogicalKeyboardKey.arrowRight): const _NextIntent(),
    };

    // 动作处理
    final Map<Type, Action<Intent>> actions = {
      _PlayPauseIntent: CallbackAction<_PlayPauseIntent>(
        onInvoke: (_) {
          _togglePlayPause();
          return null;
        },
      ),
      _PreviousIntent: CallbackAction<_PreviousIntent>(
        onInvoke: (_) {
          _playPrevious();
          return null;
        },
      ),
      _NextIntent: CallbackAction<_NextIntent>(
        onInvoke: (_) {
          _playNext();
          return null;
        },
      ),
    };

    Widget scaffold = Scaffold(
        appBar: AppBar(
          title: const Text('音乐播放器'),
          actions: [
          // Web平台不显示缓存管理（只使用内存缓存，意义不大）
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.storage),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CacheSettingsScreen(),
                  ),
                );
              },
              tooltip: '缓存管理',
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Navigator.pushNamed(context, '/music_shares'),
            tooltip: '分享管理',
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _isUploading ? null : _uploadMusic,
            tooltip: '上传音乐',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 搜索框
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: '搜索标题、艺术家或专辑...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchKeyword.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: _clearSearch,
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _performSearch(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _performSearch,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('搜索'),
                      ),
                    ],
                  ),
                ),
                
                // 搜索结果提示
                if (_searchKeyword.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.blue[50],
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '搜索 "$_searchKeyword" 的结果：共 $_total 首',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        TextButton(
                          onPressed: _clearSearch,
                          child: const Text('清除搜索'),
                        ),
                      ],
                    ),
                  ),
                
                // 音乐列表
                Expanded(
                  child: _musicList.isEmpty
                      ? const Center(
                          child: Text(
                            '暂无音乐\n点击右上角上传音乐',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _musicList.length,
                          itemBuilder: (context, index) {
                            final music = _musicList[index];
                            final isCurrentPlaying = _playerService.currentPlayingId == music['id'];
                            
                            return Slidable(
                              key: ValueKey(music['id']),
                              endActionPane: ActionPane(
                                motion: const ScrollMotion(),
                                extentRatio: 0.2, // 减小滑动区域宽度
                                children: [
                                  SlidableAction(
                                    onPressed: (context) => _deleteMusic(music['id']),
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    icon: Icons.delete,
                                    label: '删除',
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                ],
                              ),
                              child: Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                color: isCurrentPlaying ? Colors.blue[50] : null,
                                child: ListTile(
                                  leading: Icon(
                                    isCurrentPlaying && _playerService.isPlaying
                                        ? Icons.music_note
                                        : Icons.music_note_outlined,
                                    color: isCurrentPlaying ? Colors.blue : Colors.grey,
                                    size: 40,
                                  ),
                                  title: Text(
                                    music['title'] ?? '未知标题',
                                    style: TextStyle(
                                      fontWeight: isCurrentPlaying ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${music['artist'] ?? '未知艺术家'} • ${music['file_size_str'] ?? ''}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.share, color: Colors.green),
                                    onPressed: () => _shareMusic(music['id']),
                                    tooltip: '分享',
                                  ),
                                  onTap: () => _playMusic(music['id']),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // 播放器控制栏
                if (_playerService.currentPlayingId != null)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 当前播放歌曲
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _playerService.currentTitle ?? '未知',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // 歌词按钮
                            IconButton(
                              icon: Icon(
                                _currentLyrics != null ? Icons.lyrics : Icons.lyrics_outlined,
                                color: _currentLyrics != null ? Colors.blue : Colors.grey,
                              ),
                              onPressed: _openLyricsDetailScreen,
                              tooltip: '歌词',
                            ),
                            // 歌词管理按钮
                            IconButton(
                              icon: const Icon(Icons.edit_note),
                              onPressed: _showLyricsManageDialog,
                              tooltip: '管理歌词',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // 进度条
                        Row(
                          children: [
                            Text(_playerService.formatDuration(_playerService.currentPosition)),
                            Expanded(
                              child: Slider(
                                value: _playerService.currentPosition.clamp(0.0, _playerService.totalDuration),
                                min: 0.0,
                                max: _playerService.totalDuration > 0 ? _playerService.totalDuration : 1.0,
                                onChanged: (value) {
                                  // 不需要本地状态更新
                                },
                                onChangeEnd: _seek,
                              ),
                            ),
                            Text(_playerService.formatDuration(_playerService.totalDuration)),
                          ],
                        ),
                        
                        // 播放控制按钮
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 播放模式按钮
                            IconButton(
                              icon: Icon(_getPlayModeIcon()),
                              iconSize: 28,
                              onPressed: () {
                                _playerService.togglePlayMode();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_getPlayModeName()),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              tooltip: _getPlayModeName(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.skip_previous),
                              iconSize: 40,
                              onPressed: _playPrevious,
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: Icon(_playerService.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                              iconSize: 64,
                              onPressed: _togglePlayPause,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.skip_next),
                              iconSize: 40,
                              onPressed: _playNext,
                            ),
                            const SizedBox(width: 8),
                            // 占位，保持对称
                            const SizedBox(width: 28),
                          ],
                        ),
                      ],
                    ),
                  ),

                // 分页控制
                if (_totalPages > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _currentPage > 1
                              ? () => _loadMusicList(page: _currentPage - 1, keyword: _searchKeyword)
                              : null,
                        ),
                        Text('$_currentPage / $_totalPages'),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _currentPage < _totalPages
                              ? () => _loadMusicList(page: _currentPage + 1, keyword: _searchKeyword)
                              : null,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );

    // 使用 Shortcuts 和 Actions 处理键盘事件（所有平台都支持）
    return FocusScope(
      autofocus: kIsWeb || isDesktop, // Web 端和桌面端自动获取焦点
      child: Shortcuts(
        shortcuts: shortcuts,
        child: Actions(
          actions: actions,
          child: Focus(
            autofocus: kIsWeb || isDesktop, // Web 端和桌面端自动获取焦点
            canRequestFocus: true,
            onKeyEvent: (FocusNode node, KeyEvent event) {
              // 作为备选方案，直接处理键盘事件（特别是 Web 端）
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.space) {
                  _togglePlayPause();
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  _playPrevious();
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  _playNext();
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: scaffold,
          ),
        ),
      ),
    );
  }

}

// 键盘快捷键 Intent 类
class _PlayPauseIntent extends Intent {
  const _PlayPauseIntent();
}

class _PreviousIntent extends Intent {
  const _PreviousIntent();
}

class _NextIntent extends Intent {
  const _NextIntent();
}
