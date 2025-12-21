import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 播放模式
enum PlayMode {
  sequence,  // 顺序播放
  shuffle,   // 随机播放
  repeat,    // 单曲循环
}

/// 全局音乐播放器服务（单例模式）
class MusicPlayerService extends ChangeNotifier {
  // 单例实例
  static final MusicPlayerService _instance = MusicPlayerService._internal();
  
  factory MusicPlayerService() {
    return _instance;
  }
  
  MusicPlayerService._internal() {
    _initAudioPlayer();
  }
  
  // 音频播放器
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // 播放器状态
  int? _currentPlayingId;
  String? _currentTitle;
  String? _currentArtist;
  String? _currentStreamUrl; // 保存当前播放的URL，用于单曲循环
  bool _isPlaying = false;
  double _currentPosition = 0.0;
  double _totalDuration = 0.0;
  
  // 播放模式
  PlayMode _playMode = PlayMode.sequence;
  
  // 播放列表（用于自动切换下一首）
  List<Map<String, dynamic>> _playlist = [];
  
  // 播放列表回调（用于获取完整列表和Token）
  Future<void> Function()? _onPlayNext;
  Future<void> Function()? _onPlayPrevious;
  
  // 流订阅
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  
  // Getters
  int? get currentPlayingId => _currentPlayingId;
  String? get currentTitle => _currentTitle;
  String? get currentArtist => _currentArtist;
  bool get isPlaying => _isPlaying;
  double get currentPosition => _currentPosition;
  double get totalDuration => _totalDuration;
  AudioPlayer get audioPlayer => _audioPlayer;
  PlayMode get playMode => _playMode;
  List<Map<String, dynamic>> get playlist => _playlist;
  
  // 初始化音频播放器
  void _initAudioPlayer() {
    // 监听播放位置
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      _currentPosition = position.inSeconds.toDouble();
      notifyListeners();
    });
    
    // 监听总时长
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      _totalDuration = duration.inSeconds.toDouble();
      notifyListeners();
    });
    
    // 监听播放状态
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
      
      // 如果播放完成，自动播放下一首（如果有的话）
      if (state == PlayerState.completed) {
        // 使用 Future.microtask 来异步调用
        Future.microtask(() => _onPlaybackCompleted());
      }
    });
  }
  
  // 播放音乐
  Future<void> playMusic({
    required int musicId,
    required String streamUrl,
    String? title,
    String? artist,
    bool forceReplay = false, // 新增参数：强制重新播放
  }) async {
    try {
      if (_currentPlayingId == musicId && !forceReplay) {
        // 同一首歌且不强制重播，切换播放/暂停
        if (_isPlaying) {
          await pause();
        } else {
          await resume();
        }
      } else {
        // 播放新歌曲或强制重新播放
        _currentPlayingId = musicId;
        _currentTitle = title;
        _currentArtist = artist;
        _currentStreamUrl = streamUrl; // 保存URL用于单曲循环
        _currentPosition = 0.0;
        notifyListeners();
        
        debugPrint('🎵 播放音乐: $title - $artist');
        debugPrint('🎵 播放URL: $streamUrl');
        
        // 检测是否是本地文件（file:// URI）
        Source audioSource;
        if (streamUrl.startsWith('file://')) {
          // 本地文件：提取文件路径并使用 DeviceFileSource
          final uri = Uri.parse(streamUrl);
          // Windows 路径处理：移除前导斜杠（如果有）
          String filePath = uri.path;
          if (filePath.startsWith('/') && filePath.length > 1 && filePath[1] == ':') {
            // Windows 绝对路径，移除前导斜杠
            filePath = filePath.substring(1);
          }
          audioSource = DeviceFileSource(filePath);
          debugPrint('📦 使用本地文件播放: $filePath');
        } else {
          // 网络URL：使用 UrlSource
          audioSource = UrlSource(streamUrl);
        }
        
        // 使用 audioplayers 播放
        await _audioPlayer.play(audioSource);
      }
    } catch (e) {
      debugPrint('❌ 播放失败: $e');
      rethrow;
    }
  }
  
  // 暂停
  Future<void> pause() async {
    await _audioPlayer.pause();
  }
  
  // 继续播放
  Future<void> resume() async {
    await _audioPlayer.resume();
  }
  
  // 停止
  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentPlayingId = null;
    _currentTitle = null;
    _currentArtist = null;
    _currentStreamUrl = null;
    _isPlaying = false;
    _currentPosition = 0.0;
    _totalDuration = 0.0;
    notifyListeners();
  }
  
  // 跳转到指定位置
  Future<void> seek(double seconds) async {
    await _audioPlayer.seek(Duration(seconds: seconds.toInt()));
  }
  
  // 设置播放列表和回调
  void setPlaylist(
    List<Map<String, dynamic>> playlist, {
    Future<void> Function()? onPlayNext,
    Future<void> Function()? onPlayPrevious,
  }) {
    _playlist = playlist;
    _onPlayNext = onPlayNext;
    _onPlayPrevious = onPlayPrevious;
    notifyListeners();
  }
  
  // 切换播放模式
  void togglePlayMode() {
    switch (_playMode) {
      case PlayMode.sequence:
        _playMode = PlayMode.shuffle;
        break;
      case PlayMode.shuffle:
        _playMode = PlayMode.repeat;
        break;
      case PlayMode.repeat:
        _playMode = PlayMode.sequence;
        break;
    }
    debugPrint('🎵 播放模式切换为: ${_getPlayModeName()}');
    notifyListeners();
  }
  
  // 获取播放模式名称
  String _getPlayModeName() {
    switch (_playMode) {
      case PlayMode.sequence:
        return '顺序播放';
      case PlayMode.shuffle:
        return '随机播放';
      case PlayMode.repeat:
        return '单曲循环';
    }
  }
  
  // 获取播放模式图标名称
  String getPlayModeIconName() {
    switch (_playMode) {
      case PlayMode.sequence:
        return 'sequence';
      case PlayMode.shuffle:
        return 'shuffle';
      case PlayMode.repeat:
        return 'repeat';
    }
  }
  
  // 播放完成回调
  Future<void> _onPlaybackCompleted() async {
    debugPrint('🎵 播放完成，当前模式: ${_getPlayModeName()}');
    
    switch (_playMode) {
      case PlayMode.sequence:
        // 顺序播放：播放下一首
        await _playNextInSequence();
        break;
      case PlayMode.shuffle:
        // 随机播放：随机选择下一首
        await _playNextInShuffle();
        break;
      case PlayMode.repeat:
        // 单曲循环：重新播放当前歌曲
        await _repeatCurrentSong();
        break;
    }
  }
  
  // 顺序播放下一首
  Future<void> _playNextInSequence() async {
    if (_playlist.isEmpty || _currentPlayingId == null) return;
    
    final currentIndex = _playlist.indexWhere((m) => m['id'] == _currentPlayingId);
    if (currentIndex < _playlist.length - 1) {
      // 还有下一首
      debugPrint('🎵 顺序播放下一首');
      await _onPlayNext?.call();
    } else {
      // 已经是最后一首，循环到第一首
      debugPrint('🎵 顺序播放完成，循环到第一首');
      await _onPlayNext?.call();
    }
  }
  
  // 随机播放下一首
  Future<void> _playNextInShuffle() async {
    if (_playlist.isEmpty) return;
    
    final random = Random();
    final currentIndex = _playlist.indexWhere((m) => m['id'] == _currentPlayingId);
    
    // 随机选择一首（排除当前歌曲）
    int nextIndex;
    if (_playlist.length == 1) {
      nextIndex = 0;
    } else {
      do {
        nextIndex = random.nextInt(_playlist.length);
      } while (nextIndex == currentIndex);
    }
    
    debugPrint('🎵 随机播放下一首: index=$nextIndex');
    await _onPlayNext?.call();
  }
  
  // 单曲循环
  Future<void> _repeatCurrentSong() async {
    debugPrint('🎵 单曲循环：重新播放');
    
    if (_currentStreamUrl == null) {
      debugPrint('❌ 没有可播放的URL');
      return;
    }
    
    try {
      // 重新播放当前歌曲（从头开始）
      _currentPosition = 0.0;
      notifyListeners();
      
      // 使用 stop 然后 play 来确保重新开始
      await _audioPlayer.stop();
      
      // 检测是否是本地文件
      Source audioSource;
      if (_currentStreamUrl!.startsWith('file://')) {
        final uri = Uri.parse(_currentStreamUrl!);
        // Windows 路径处理：移除前导斜杠（如果有）
        String filePath = uri.path;
        if (filePath.startsWith('/') && filePath.length > 1 && filePath[1] == ':') {
          // Windows 绝对路径，移除前导斜杠
          filePath = filePath.substring(1);
        }
        audioSource = DeviceFileSource(filePath);
      } else {
        audioSource = UrlSource(_currentStreamUrl!);
      }
      
      await _audioPlayer.play(audioSource);
      
      debugPrint('✅ 单曲循环：重新播放成功');
    } catch (e) {
      debugPrint('❌ 单曲循环重新播放失败: $e');
    }
  }
  
  // 停止并重置播放器（用于退出登录等场景）
  Future<void> stopAndReset() async {
    try {
      await _audioPlayer.stop();
      _currentPlayingId = null;
      _currentTitle = null;
      _currentArtist = null;
      _currentStreamUrl = null;
      _isPlaying = false;
      _currentPosition = 0.0;
      _totalDuration = 0.0;
      _playlist.clear();
      _onPlayNext = null;
      _onPlayPrevious = null;
      notifyListeners();
      debugPrint('🎵 播放器已停止并重置');
    } catch (e) {
      debugPrint('❌ 停止播放器失败: $e');
    }
  }
  
  // 清理资源
  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
  
  // 格式化时长
  String formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

