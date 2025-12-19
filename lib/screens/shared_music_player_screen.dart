import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import '../config/api_config.dart';

class SharedMusicPlayerScreen extends StatefulWidget {
  final String shareToken;
  
  const SharedMusicPlayerScreen({
    super.key,
    required this.shareToken,
  });

  @override
  State<SharedMusicPlayerScreen> createState() => _SharedMusicPlayerScreenState();
}

class _SharedMusicPlayerScreenState extends State<SharedMusicPlayerScreen> {
  Map<String, dynamic>? _musicData;
  bool _isLoading = true;
  bool _isPlaying = false;
  double _currentPosition = 0.0;
  double _totalDuration = 0.0;
  String? _errorMessage;
  
  // 音频播放器
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  @override
  void initState() {
    super.initState();
    _loadSharedMusic();
    _initAudioPlayer();
  }
  
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
  
  // 初始化音频播放器
  void _initAudioPlayer() {
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position.inSeconds.toDouble();
        });
      }
    });
    
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration.inSeconds.toDouble();
        });
      }
    });
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }
  
  // 加载分享的音乐信息
  Future<void> _loadSharedMusic() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/music/share/detail?token=${widget.shareToken}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          setState(() {
            _musicData = data;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? '分享不存在或已失效';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = '加载失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载失败: $e';
        _isLoading = false;
      });
    }
  }
  
  // 播放/暂停
  Future<void> _togglePlayPause() async {
    if (_musicData == null) return;
    
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_currentPosition == 0 && !_isPlaying) {
        // 首次播放
        final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
        final streamUrl = '$baseUrl${_musicData!['stream_url']}';
        await _audioPlayer.play(UrlSource(streamUrl));
      } else {
        await _audioPlayer.resume();
      }
    }
  }
  
  // 拖动进度条
  Future<void> _seek(double value) async {
    await _audioPlayer.seek(Duration(seconds: value.toInt()));
  }
  
  // 格式化时长
  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分享的音乐'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 封面图片占位
                        Container(
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.music_note,
                            size: 120,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 48),
                        
                        // 歌曲标题
                        Text(
                          _musicData!['title'] ?? '未知标题',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        
                        // 艺术家
                        Text(
                          _musicData!['artist'] ?? '未知艺术家',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 48),
                        
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
                                activeColor: Colors.blue,
                              ),
                            ),
                            Text(_formatDuration(_totalDuration)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // 播放按钮
                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          ),
                          iconSize: 80,
                          color: Colors.blue,
                          onPressed: _togglePlayPause,
                        ),
                        const SizedBox(height: 48),
                        
                        // 提示文本
                        Text(
                          '这是一首分享的音乐\n喜欢就下载我们的APP听更多好音乐吧！',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

