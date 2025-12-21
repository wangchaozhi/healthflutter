import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/music_player_service.dart';
import '../services/cache_service.dart';
import '../widgets/lyrics_widget.dart';
import '../widgets/lyrics_manage_dialog.dart';

/// 歌词特写页面 - 全屏歌词显示
class LyricsDetailScreen extends StatefulWidget {
  final int musicId;
  final String musicTitle;
  final String musicArtist;
  final String? lyricsContent;
  final Function()? onLyricsChanged;
  final Future<void> Function()? onPlayNext; // 播放下一首回调
  final Future<void> Function()? onPlayPrevious; // 播放上一首回调

  const LyricsDetailScreen({
    super.key,
    required this.musicId,
    required this.musicTitle,
    required this.musicArtist,
    this.lyricsContent,
    this.onLyricsChanged,
    this.onPlayNext,
    this.onPlayPrevious,
  });

  @override
  State<LyricsDetailScreen> createState() => _LyricsDetailScreenState();
}

class _LyricsDetailScreenState extends State<LyricsDetailScreen> {
  final MusicPlayerService _playerService = MusicPlayerService();
  final CacheService _cacheService = CacheService();
  String? _currentLyrics;
  int? _lastMusicId; // 记录上一首歌曲的ID
  String _currentTitle = '';
  String _currentArtist = '';

  @override
  void initState() {
    super.initState();
    _currentLyrics = widget.lyricsContent;
    _lastMusicId = widget.musicId;
    _currentTitle = widget.musicTitle;
    _currentArtist = widget.musicArtist;
    _playerService.addListener(_onPlayerStateChanged);
  }

  @override
  void dispose() {
    _playerService.removeListener(_onPlayerStateChanged);
    super.dispose();
  }

  void _onPlayerStateChanged() {
    if (mounted) {
      // 检查是否切换到了新歌曲
      if (_playerService.currentPlayingId != null && 
          _playerService.currentPlayingId != _lastMusicId) {
        _lastMusicId = _playerService.currentPlayingId;
        _currentTitle = _playerService.currentTitle ?? '未知';
        _currentArtist = _playerService.currentArtist ?? '未知艺术家';
        
        // 自动加载新歌曲的歌词
        _loadLyrics(_playerService.currentPlayingId!);
      }
      
      setState(() {
        // 触发UI更新
      });
    }
  }

  // 加载歌词
  Future<void> _loadLyrics(int musicId) async {
    try {
      // 先从缓存读取
      final cachedLyrics = await _cacheService.getCachedLyrics(musicId);
      if (cachedLyrics != null) {
        debugPrint('📦 从缓存加载歌词: $musicId');
        if (mounted) {
          setState(() {
            _currentLyrics = cachedLyrics;
          });
        }
        return;
      }

      // 缓存不存在，从服务器获取
      debugPrint('🌐 从服务器加载歌词: $musicId');
      final token = await ApiService.getToken();
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
          
          if (mounted) {
            setState(() {
              _currentLyrics = lyricsContent;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _currentLyrics = null;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('加载歌词失败: $e');
      if (mounted) {
        setState(() {
          _currentLyrics = null;
        });
      }
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

    showDialog(
      context: context,
      builder: (context) => LyricsManageDialog(
        musicId: _playerService.currentPlayingId!,
        musicTitle: _currentTitle,
        musicArtist: _currentArtist,
        onLyricsChanged: () {
          // 重新加载当前歌曲的歌词
          if (_playerService.currentPlayingId != null) {
            _loadLyrics(_playerService.currentPlayingId!);
          }
          // 同时通知父组件（MusicPlayerScreen）更新歌词
          widget.onLyricsChanged?.call();
        },
      ),
    );
  }

  // 拖动进度条
  Future<void> _seek(double value) async {
    await _playerService.seek(value);
  }

  // 播放/暂停
  Future<void> _togglePlayPause() async {
    if (_playerService.isPlaying) {
      await _playerService.pause();
    } else {
      await _playerService.resume();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 使用渐变背景
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade900,
              Colors.blue.shade700,
              Colors.blue.shade500,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部导航栏
              _buildTopBar(),

              // 歌曲信息卡片
              _buildMusicInfoCard(),

              // 歌词显示区域（占据主要空间）
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: LyricsWidget(
                      lyricsContent: _currentLyrics,
                      currentPosition: _playerService.currentPosition,
                      onTap: _showLyricsManageDialog,
                      textColor: Colors.white70, // 深色背景用白色文字
                      highlightColor: Colors.white, // 高亮用纯白色
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 播放控制区域
              _buildControlPanel(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部导航栏
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            iconSize: 32,
            onPressed: () => Navigator.pop(context),
            tooltip: '返回',
          ),
          
          const Spacer(),
          
          // 歌词管理按钮
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit_note, color: Colors.blue),
                          title: const Text('管理歌词'),
                          onTap: () {
                            Navigator.pop(context);
                            _showLyricsManageDialog();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.share, color: Colors.green),
                          title: const Text('分享歌曲'),
                          onTap: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('分享功能开发中...')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            tooltip: '更多选项',
          ),
        ],
      ),
    );
  }

  /// 歌曲信息卡片
  Widget _buildMusicInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // 歌曲封面占位符（可以后续添加）
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.music_note,
              size: 60,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 歌曲名称
          Text(
            _currentTitle,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // 艺术家名称
          Text(
            _currentArtist,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 播放控制面板
  Widget _buildControlPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // 进度条
          Row(
            children: [
              Text(
                _playerService.formatDuration(_playerService.currentPosition),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withValues(alpha: 0.3),
                  ),
                  child: Slider(
                    value: _playerService.currentPosition.clamp(
                      0.0,
                      _playerService.totalDuration,
                    ),
                    min: 0.0,
                    max: _playerService.totalDuration > 0
                        ? _playerService.totalDuration
                        : 1.0,
                    onChanged: (value) {
                      // 实时更新UI
                    },
                    onChangeEnd: _seek,
                  ),
                ),
              ),
              Text(
                _playerService.formatDuration(_playerService.totalDuration),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 播放控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 播放模式按钮
              IconButton(
                icon: Icon(_getPlayModeIcon()),
                color: Colors.white,
                iconSize: 28,
                onPressed: () {
                  _playerService.togglePlayMode();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_getPlayModeName()),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                tooltip: _getPlayModeName(),
              ),

              // 上一首按钮
              IconButton(
                icon: const Icon(Icons.skip_previous),
                color: Colors.white,
                iconSize: 40,
                onPressed: widget.onPlayPrevious != null
                    ? () async {
                        await widget.onPlayPrevious!();
                      }
                    : null,
              ),

              // 播放/暂停按钮
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    _playerService.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  color: Colors.blue.shade700,
                  iconSize: 40,
                  onPressed: _togglePlayPause,
                  tooltip: _playerService.isPlaying ? '暂停' : '播放',
                ),
              ),

              // 下一首按钮
              IconButton(
                icon: const Icon(Icons.skip_next),
                color: Colors.white,
                iconSize: 40,
                onPressed: widget.onPlayNext != null
                    ? () async {
                        await widget.onPlayNext!();
                      }
                    : null,
              ),

              // 占位符（保持对称）
              const SizedBox(width: 28),
            ],
          ),
        ],
      ),
    );
  }
}
