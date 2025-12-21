import 'package:flutter/material.dart';
import 'dart:async';

/// 歌词行数据
class LyricLine {
  final Duration time;
  final String text;

  LyricLine({required this.time, required this.text});
}

/// 歌词显示组件
class LyricsWidget extends StatefulWidget {
  final String? lyricsContent; // LRC格式的歌词内容
  final double currentPosition; // 当前播放位置（秒）
  final VoidCallback? onTap; // 点击回调
  final Color? textColor; // 文字颜色
  final Color? highlightColor; // 高亮颜色

  const LyricsWidget({
    super.key,
    this.lyricsContent,
    required this.currentPosition,
    this.onTap,
    this.textColor,
    this.highlightColor,
  });

  @override
  State<LyricsWidget> createState() => _LyricsWidgetState();
}

class _LyricsWidgetState extends State<LyricsWidget> {
  List<LyricLine> _lyricLines = [];
  int _currentLineIndex = 0;
  final ScrollController _scrollController = ScrollController();
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _parseLyrics();
    // 启动定时器，每100ms检查一次当前行
    _startUpdateTimer();
  }

  @override
  void didUpdateWidget(LyricsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 如果歌词内容变化，重新解析
    if (widget.lyricsContent != oldWidget.lyricsContent) {
      _parseLyrics();
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// 启动更新定时器
  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        _updateCurrentLine();
      }
    });
  }

  /// 解析LRC格式歌词
  void _parseLyrics() {
    _lyricLines.clear();
    
    if (widget.lyricsContent == null || widget.lyricsContent!.isEmpty) {
      setState(() {
        _lyricLines = [];
        _currentLineIndex = 0;
      });
      return;
    }

    final lines = widget.lyricsContent!.split('\n');
    final RegExp timeRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');

    for (var line in lines) {
      final match = timeRegex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final milliseconds = int.parse(match.group(3)!.padRight(3, '0'));
        
        final time = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );
        
        // 移除时间标签，获取歌词文本
        final text = line.replaceAll(timeRegex, '').trim();
        if (text.isNotEmpty) {
          _lyricLines.add(LyricLine(time: time, text: text));
        }
      }
    }

    // 按时间排序
    _lyricLines.sort((a, b) => a.time.compareTo(b.time));
    
    setState(() {
      _currentLineIndex = 0;
    });
  }

  /// 更新当前行索引
  void _updateCurrentLine() {
    if (_lyricLines.isEmpty || !mounted) return;

    final currentTime = Duration(milliseconds: (widget.currentPosition * 1000).toInt());
    
    // 找到当前应该显示的歌词行
    int newIndex = 0;
    for (int i = 0; i < _lyricLines.length; i++) {
      if (_lyricLines[i].time.compareTo(currentTime) <= 0) {
        newIndex = i;
      } else {
        break;
      }
    }

    if (newIndex != _currentLineIndex) {
      if (mounted) {
        setState(() {
          _currentLineIndex = newIndex;
        });
        
        // 自动滚动到当前行
        _scrollToCurrentLine();
      }
    }
  }

  /// 滚动到当前行（居中显示）
  void _scrollToCurrentLine() {
    if (!_scrollController.hasClients || _lyricLines.isEmpty) return;
    
    // 使用 WidgetsBinding 确保在下一帧执行，避免布局冲突
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      
      // 行高和padding必须与UI中的设置一致
      const itemHeight = 50.0;
      const topPadding = 0.0; // 更新为新的顶部padding
      
      double targetOffset;
      
      // 特殊处理：前几句歌词靠近顶部，不居中
      if (_currentLineIndex <= 2) {
        // 前三句歌词靠近上边框，只保留少量间距
        targetOffset = _currentLineIndex * itemHeight;
      } else {
        // 后续歌词居中显示
        final itemCenter = topPadding + (_currentLineIndex * itemHeight) + (itemHeight / 2);
        final viewportCenter = _scrollController.position.viewportDimension / 2;
        targetOffset = itemCenter - viewportCenter;
      }
      
      // 限制在可滚动范围内
      final clampedOffset = targetOffset.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );
      
      // 平滑滚动到目标位置
      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // 根据主题自动选择颜色
    final defaultTextColor = widget.textColor ?? 
        (Theme.of(context).brightness == Brightness.dark 
            ? Colors.white70 
            : Colors.grey[600]);
    final defaultHighlightColor = widget.highlightColor ?? 
        (Theme.of(context).brightness == Brightness.dark 
            ? Colors.white 
            : Colors.blue);

    if (widget.lyricsContent == null || widget.lyricsContent!.isEmpty) {
      // 无歌词时显示提示
      return GestureDetector(
        onTap: widget.onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lyrics_outlined,
                size: 64,
                color: defaultTextColor?.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                '暂无歌词',
                style: TextStyle(
                  fontSize: 18,
                  color: defaultTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '点击上传或绑定歌词',
                style: TextStyle(
                  fontSize: 14,
                  color: defaultTextColor?.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_lyricLines.isEmpty) {
      return Center(
        child: Text(
          '歌词格式错误',
          style: TextStyle(
            fontSize: 14,
            color: defaultTextColor,
          ),
        ),
      );
    }

    // 显示歌词列表
    return ListView.builder(
      controller: _scrollController,
      itemCount: _lyricLines.length,
      padding: const EdgeInsets.only(top: 0, bottom: 200), // 顶部完全贴边，底部保持足够空间
      itemBuilder: (context, index) {
        final line = _lyricLines[index];
        final isCurrent = index == _currentLineIndex;
        
        return Container(
          height: 50, // 固定行高
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: isCurrent ? 22 : 16, // 当前行更大
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent ? defaultHighlightColor : defaultTextColor,
              height: 1.5, // 行高
            ),
            child: Text(
              line.text,
              textAlign: TextAlign.center,
              maxLines: 2, // 允许最多2行
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}
