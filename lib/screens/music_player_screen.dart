import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../utils/debounce.dart';

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

  // 播放器状态
  int? _currentPlayingId;
  bool _isPlaying = false;
  double _currentPosition = 0.0;
  double _totalDuration = 0.0;
  
  // 音频播放器
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  // 防抖
  final DebounceState _uploadDebounce = DebounceState();
  final DebounceState _deleteDebounce = DebounceState();
  
  // 搜索
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();
    _loadMusicList();
    _initAudioPlayer();
  }
  
  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  // 初始化音频播放器
  void _initAudioPlayer() {
    // 监听播放位置
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position.inSeconds.toDouble();
        });
      }
    });
    
    // 监听总时长
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration.inSeconds.toDouble();
        });
      }
    });
    
    // 监听播放状态
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  // 加载音乐列表
  Future<void> _loadMusicList({int page = 1, String? keyword}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await ApiService.getToken();
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
            final token = await ApiService.getToken();
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

  // 删除音乐
  Future<void> _deleteMusic(int musicId) async {
    if (!_deleteDebounce.canExecute) return;

    await _deleteDebounce.execute(
      action: () async {
        try {
          final token = await ApiService.getToken();
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
              if (_currentPlayingId == musicId) {
                await _audioPlayer.stop();
                setState(() {
                  _currentPlayingId = null;
                  _isPlaying = false;
                  _currentPosition = 0.0;
                  _totalDuration = 0.0;
                });
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
  Future<void> _playMusic(int musicId) async {
    try {
      if (_currentPlayingId == musicId) {
        // 同一首歌，切换播放/暂停
        if (_isPlaying) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.resume();
        }
      } else {
        // 播放新歌曲
        setState(() {
          _currentPlayingId = musicId;
          _currentPosition = 0.0;
        });
        
        final token = await ApiService.getToken();
        if (token == null) {
          debugPrint('Token为空，无法播放');
          return;
        }
        
        // 构建流式传输URL（通过URL参数传递token）
        final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
        final streamUrl = '$baseUrl/api/music/stream?id=$musicId&token=$token';
        
        debugPrint('播放URL: $streamUrl');
        
        // 使用 audioplayers 播放
        await _audioPlayer.play(UrlSource(streamUrl));
      }
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
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
  }
  
  // 拖动进度条
  Future<void> _seek(double value) async {
    await _audioPlayer.seek(Duration(seconds: value.toInt()));
  }
  
  // 上一首
  void _playPrevious() {
    if (_currentPlayingId == null || _musicList.isEmpty) return;
    
    final currentIndex = _musicList.indexWhere((m) => m['id'] == _currentPlayingId);
    if (currentIndex > 0) {
      _playMusic(_musicList[currentIndex - 1]['id']);
    }
  }
  
  // 下一首
  void _playNext() {
    if (_currentPlayingId == null || _musicList.isEmpty) return;
    
    final currentIndex = _musicList.indexWhere((m) => m['id'] == _currentPlayingId);
    if (currentIndex < _musicList.length - 1) {
      _playMusic(_musicList[currentIndex + 1]['id']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('音乐播放器'),
        actions: [
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
                            final isCurrentPlaying = _currentPlayingId == music['id'];
                            
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              color: isCurrentPlaying ? Colors.blue[50] : null,
                              child: ListTile(
                                leading: Icon(
                                  isCurrentPlaying && _isPlaying
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
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        isCurrentPlaying && _isPlaying
                                            ? Icons.pause_circle
                                            : Icons.play_circle,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () => _playMusic(music['id']),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteMusic(music['id']),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // 播放器控制栏
                if (_currentPlayingId != null)
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
                        Text(
                          _musicList.firstWhere(
                            (m) => m['id'] == _currentPlayingId,
                            orElse: () => {'title': '未知'},
                          )['title'] ?? '未知',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        
                        // 进度条
                        Row(
                          children: [
                            Text(_formatDuration(_currentPosition)),
                            Expanded(
                              child: Slider(
                                value: _currentPosition.clamp(0.0, _totalDuration),
                                min: 0.0,
                                max: _totalDuration > 0 ? _totalDuration : 1.0,
                                onChanged: (value) {
                                  setState(() {
                                    _currentPosition = value;
                                  });
                                },
                                onChangeEnd: _seek,
                              ),
                            ),
                            Text(_formatDuration(_totalDuration)),
                          ],
                        ),
                        
                        // 播放控制按钮
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.skip_previous),
                              iconSize: 40,
                              onPressed: _playPrevious,
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
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
  }

  // 格式化时长
  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
