import 'dart:async';

/// 防抖工具类
class Debounce {
  /// 时间戳防抖：在指定时间内只执行一次
  static DateTime? _lastActionTime;
  static const int _defaultDelay = 500; // 默认500ms

  /// 执行防抖操作（时间戳方式）
  /// [delay] 防抖延迟时间（毫秒），默认500ms
  /// 返回true表示可以执行，false表示被防抖拦截
  static bool debounceTime({int delay = _defaultDelay}) {
    final now = DateTime.now();
    if (_lastActionTime != null &&
        now.difference(_lastActionTime!).inMilliseconds < delay) {
      return false;
    }
    _lastActionTime = now;
    return true;
  }

  /// 重置时间戳防抖
  static void resetTime() {
    _lastActionTime = null;
  }
}

/// 防抖状态管理器
class DebounceState {
  bool _isProcessing = false;
  Timer? _timer;

  /// 检查是否可以执行操作
  bool get canExecute => !_isProcessing;

  /// 开始处理（设置处理状态）
  void start() {
    _isProcessing = true;
  }

  /// 结束处理（清除处理状态）
  void end() {
    _isProcessing = false;
  }

  /// 延迟结束处理（用于自动恢复）
  void endAfter(Duration duration) {
    _timer?.cancel();
    _timer = Timer(duration, () {
      _isProcessing = false;
    });
  }

  /// 执行防抖操作（状态方式）
  /// [action] 要执行的操作
  /// [onStart] 开始处理时的回调
  /// [onEnd] 结束处理时的回调
  Future<T?> execute<T>({
    required Future<T> Function() action,
    void Function()? onStart,
    void Function()? onEnd,
  }) async {
    if (!canExecute) {
      return null;
    }

    start();
    onStart?.call();

    try {
      final result = await action();
      return result;
    } finally {
      end();
      onEnd?.call();
    }
  }

  /// 清理资源
  void dispose() {
    _timer?.cancel();
    _isProcessing = false;
  }
}

