# 歌词同步功能说明

## 实现原理

### 1. 实时同步机制

歌词组件现在使用 **定时器** 实时检查播放进度，确保歌词与音乐完美同步：

```dart
// 每100ms检查一次当前播放位置
Timer.periodic(const Duration(milliseconds: 100), (timer) {
  _updateCurrentLine(); // 更新当前歌词行
});
```

### 2. 同步流程

1. **初始化阶段**
   - 解析LRC格式歌词
   - 提取时间标签和文本
   - 按时间顺序排序

2. **播放阶段**
   - 定时器每100ms检查播放位置
   - 根据当前播放时间查找对应歌词行
   - 如果歌词行变化，触发UI更新和滚动

3. **滚动逻辑**
   - 当前行自动滚动到屏幕中央
   - 使用平滑动画过渡（300ms）
   - 高亮显示当前行

## LRC歌词格式

### 标准格式
```lrc
[00:12.50]第一句歌词
[00:17.80]第二句歌词
[00:23.10]第三句歌词
```

### 时间标签说明
- `[mm:ss.xx]` 格式
- `mm`: 分钟（00-99）
- `ss`: 秒钟（00-59）
- `xx`: 毫秒（00-99）或（000-999）

### 示例
```lrc
[ti:歌曲名称]
[ar:艺术家]
[al:专辑]
[00:00.00]
[00:05.50]天空中飘着云朵
[00:10.80]心中满是期待
[00:16.20]梦想在远方召唤
```

## 精确度说明

### 时间精度
- **检查频率**: 100ms（0.1秒）
- **LRC精度**: 支持10ms精度（2-3位毫秒）
- **实际精度**: 约100-200ms的误差

### 优化建议

如果发现歌词不同步，可能的原因和解决方法：

1. **歌词时间标签不准确**
   - 使用专业的LRC编辑器重新制作歌词
   - 推荐工具：LyricEditor、LRC Maker

2. **音频文件有前奏或静音**
   - 调整LRC文件中的时间标签
   - 如果音频有2秒前奏，所有时间标签减2秒

3. **播放器延迟**
   - 正常现象，约100-200ms延迟
   - 可以在LRC文件中微调时间补偿

## 调整歌词时间

### 方法1：整体偏移

如果所有歌词都慢了1秒：
```
原始：[00:05.50]歌词
调整：[00:04.50]歌词  （减1秒）
```

如果所有歌词都快了1秒：
```
原始：[00:05.50]歌词
调整：[00:06.50]歌词  （加1秒）
```

### 方法2：使用LRC编辑器

1. 下载 LyricEditor 或在线LRC编辑器
2. 导入音频文件和歌词
3. 逐行调整时间标签
4. 导出新的LRC文件

## 测试同步效果

### 测试步骤

1. **准备测试**
   - 使用项目中的 `example_lyrics.lrc`
   - 或下载一个已知准确的LRC文件

2. **上传并绑定**
   - 播放音乐
   - 上传歌词文件
   - 进入歌词特写页面

3. **观察同步**
   - 注意当前高亮行是否与音乐匹配
   - 如果有偏差，记录大约的秒数

4. **调整时间**
   - 编辑LRC文件，整体调整时间
   - 重新上传测试

## 技术细节

### 定时器实现
```dart
@override
void initState() {
  super.initState();
  // 启动定时器，每100ms检查一次
  _updateTimer = Timer.periodic(
    const Duration(milliseconds: 100),
    (timer) {
      if (mounted) {
        _updateCurrentLine();
      }
    },
  );
}

@override
void dispose() {
  _updateTimer?.cancel(); // 清理定时器
  super.dispose();
}
```

### 查找当前行算法
```dart
void _updateCurrentLine() {
  final currentTime = Duration(
    milliseconds: (widget.currentPosition * 1000).toInt()
  );
  
  // 线性搜索找到最后一个时间小于等于当前时间的歌词
  int newIndex = 0;
  for (int i = 0; i < _lyricLines.length; i++) {
    if (_lyricLines[i].time.compareTo(currentTime) <= 0) {
      newIndex = i;
    } else {
      break;
    }
  }
  
  // 如果行号变化，更新UI和滚动
  if (newIndex != _currentLineIndex) {
    setState(() => _currentLineIndex = newIndex);
    _scrollToCurrentLine();
  }
}
```

### 滚动计算
```dart
void _scrollToCurrentLine() {
  const itemHeight = 50.0; // 每行固定高度
  
  // 计算目标位置（当前行在屏幕中央）
  final targetOffset = (_currentLineIndex * itemHeight) - 
                      (viewportHeight / 2) + 
                      (itemHeight / 2);
  
  // 平滑滚动到目标位置
  _scrollController.animateTo(
    targetOffset,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
  );
}
```

## 性能优化

### 资源使用
- **CPU**: 定时器每秒执行10次，资源占用极低
- **内存**: 歌词解析后存储在内存，约1-10KB
- **电池**: 影响可忽略

### 优化措施
1. 只在组件挂载时运行定时器
2. dispose时立即清理定时器
3. 使用线性搜索（歌词通常<200行，速度足够快）
4. 只在行号变化时更新UI

## 常见问题

### Q: 歌词总是慢半秒？
A: 编辑LRC文件，给所有时间标签减去500ms（0.5秒）

### Q: 歌词跳跃不流畅？
A: 检查LRC文件是否有重复或错误的时间标签

### Q: 某些行不显示？
A: 检查时间标签格式是否正确，必须是 `[mm:ss.xx]`

### Q: 歌词不滚动？
A: 确保：
1. LRC文件格式正确
2. 音乐正在播放
3. 重新进入歌词页面

## 未来改进

- [ ] 支持手动调整时间偏移（±N秒）
- [ ] 支持歌词实时编辑
- [ ] 支持歌词翻译对照
- [ ] 支持卡拉OK模式（逐字高亮）
- [ ] 支持手动点击跳转到指定行

---

**更新日期**: 2025-12-21
**版本**: 2.0
