import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/music_player_service.dart';
import '../utils/debounce.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  List<dynamic> _healthList = [];
  Map<String, dynamic>? _stats;
  bool _isRecordFormVisible = false;
  String _currentDateTime = '';
  
  // 表单数据
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _duration = 1;
  String _remark = '';
  String _recordTag = 'manual'; // manual=手动, auto=自动，默认手动
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  
  // 滑动删除相关
  final Map<int, double> _swipeX = {};
  
  // 防抖相关
  final DebounceState _submitDebounce = DebounceState();
  final DebounceState _deleteDebounce = DebounceState();
  final DebounceState _logoutDebounce = DebounceState();

  @override
  void initState() {
    super.initState();
    _updateDateTime();
    _loadData();
    // 每秒更新一次时间
    _startTimer();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _updateDateTime();
        _startTimer();
      }
    });
  }

  void _updateDateTime() {
    setState(() {
      _currentDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    });
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadActivities(),
      _loadStats(),
    ]);
  }

  Future<void> _loadActivities() async {
    final result = await ApiService.getActivities();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _healthList = result['list'] ?? [];
        }
      });
    }
  }

  Future<void> _loadStats() async {
    final result = await ApiService.getActivityStats();
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _stats = result['stats'];
        }
      });
    }
  }

  String _getWeekDay(DateTime date) {
    final weekdays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
    return weekdays[date.weekday % 7];
  }

  Widget _buildTagChip(bool isAuto) {
    final isAutoColor = Colors.blue;
    final manualColor = Colors.orange;
    return Row(
      children: [
        const Text('标签：'),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isAuto ? isAutoColor.withOpacity(0.15) : manualColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isAuto ? isAutoColor : manualColor,
              width: 1,
            ),
          ),
          child: Text(
            isAuto ? '自动' : '手动',
            style: TextStyle(
              color: isAuto ? isAutoColor : manualColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _showRecordForm() {
    // 防抖：500ms内不重复点击
    if (!Debounce.debounceTime(delay: 500)) {
      return;
    }
    
    setState(() {
      _isRecordFormVisible = true;
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
      _duration = 1; // 默认值为1
      _remark = '';
      _recordTag = 'manual'; // 默认手动
      _durationController.text = '1'; // 设置默认值
      _remarkController.clear();
    });
  }

  void _closeForm() {
    setState(() {
      _isRecordFormVisible = false;
    });
  }

  Future<void> _submitRecord() async {
    if (_duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入持续时间')),
      );
      return;
    }

    await _submitDebounce.execute(
      action: () async {
        final recordDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
        final recordTime = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

        final result = await ApiService.createActivity(
          recordDate: recordDate,
          recordTime: recordTime,
          duration: _duration,
          remark: _remark,
          tag: _recordTag,
        );

        if (mounted) {
          if (result['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('记录成功')),
            );
            _closeForm();
            await _loadActivities();
            await _loadStats();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['message'] ?? '记录失败')),
            );
          }
        }
      },
      onStart: () {
        if (mounted) setState(() {});
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _deleteItem(int id) async {
    await _deleteDebounce.execute(
      action: () async {
        final result = await ApiService.deleteActivity(id);
        if (mounted) {
          if (result['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('删除成功')),
            );
            await _loadActivities();
            await _loadStats();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['message'] ?? '删除失败')),
            );
          }
        }
        // 重置滑动
        if (mounted) {
          setState(() {
            _swipeX.remove(id);
          });
        }
      },
      onStart: () {
        if (mounted) setState(() {});
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _onDurationInput(String value) {
    setState(() {
      _duration = int.tryParse(value) ?? 0;
    });
  }

  void _onRemarkInput(String value) {
    setState(() {
      _remark = value;
    });
  }

  void _touchStart(DragStartDetails details, int id) {
    setState(() {
      _swipeX[id] = 0;
    });
  }

  void _touchMove(DragUpdateDetails details, int id) {
    setState(() {
      final newX = (_swipeX[id] ?? 0) + details.delta.dx;
      _swipeX[id] = newX.clamp(-100.0, 0.0);
    });
  }

  void _touchEnd(DragEndDetails details, int id) {
    setState(() {
      if ((_swipeX[id] ?? 0) < -50) {
        _swipeX[id] = -100.0;
      } else {
        _swipeX[id] = 0.0;
      }
    });
  }

  Future<void> _handleLogout() async {
    await _logoutDebounce.execute(
      action: () async {
        // 停止并重置播放器
        final playerService = MusicPlayerService();
        await playerService.stopAndReset();
        
        // 退出登录
        await ApiService.logout();
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      },
      onStart: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _durationController.dispose();
    _remarkController.dispose();
    _submitDebounce.dispose();
    _deleteDebounce.dispose();
    _logoutDebounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('健康管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.construction),
            onPressed: () {
              Navigator.of(context).pushNamed('/tools_menu');
            },
            tooltip: '工具',
          ),
          IconButton(
            icon: const Icon(Icons.public),
            onPressed: () {
              Navigator.of(context).pushNamed('/webview_menu');
            },
            tooltip: 'WebView 服务',
          ),
          IconButton(
            icon: const Icon(Icons.music_note),
            onPressed: () {
              Navigator.of(context).pushNamed('/music_player');
            },
            tooltip: '音乐播放器',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logoutDebounce.canExecute ? _handleLogout : null,
            tooltip: '退出登录',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                // 桌面端限制最大宽度为1200px
                final maxWidth = constraints.maxWidth > 1200 ? 1200.0 : constraints.maxWidth;
                return Stack(
                  children: [
                    Center(
                      child: RefreshIndicator(
                        onRefresh: _loadData,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16.0),
                          child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 日期时间显示
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _currentDateTime,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 24),
                              // 健康活动记录容器
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                            const Text(
                              '健康活动记录',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // 从最早到当前总次数
                            Builder(
                              builder: (context) {
                                final earliest = _stats?['earliest_date']?.toString();
                                final total = ((_stats?['total_auto'] ?? 0) as num).toInt() + ((_stats?['total_manual'] ?? 0) as num).toInt();
                                final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                                if (earliest != null && earliest.isNotEmpty && total > 0) {
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.indigo.shade50, Colors.purple.shade50],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.indigo.shade200, width: 1.5),
                                    ),
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '从 $earliest 至 $today 共计 ',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Colors.indigo.shade800,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          TextSpan(
                                            text: '$total',
                                            style: TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.indigo.shade700,
                                            ),
                                          ),
                                          TextSpan(
                                            text: ' 次',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Colors.indigo.shade800,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                            // 总计活动次数（自动/手动）
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '累计自动 ',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      Text(
                                        '${_stats?['total_auto'] ?? 0}',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                      Text(
                                        ' 次',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        '累计手动 ',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      Text(
                                        '${_stats?['total_manual'] ?? 0}',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                      Text(
                                        ' 次',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      '${_stats?['year_auto'] ?? 0}',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    Text(
                                      '今年自动',
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${_stats?['month_auto'] ?? 0}',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    Text(
                                      '本月自动',
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '${_stats?['year_manual'] ?? 0}',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                    Text(
                                      '今年手动',
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${_stats?['month_manual'] ?? 0}',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                    Text(
                                      '本月手动',
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 最后两次间隔天数（手机端竖向排列避免拥挤）
                            Builder(
                              builder: (context) {
                                final lastTwo = _stats?['last_two_interval'];
                                final lastTwoAuto = _stats?['last_two_auto_interval'];
                                final lastTwoManual = _stats?['last_two_manual_interval'];
                                String formatInterval(dynamic v) =>
                                    (v != null && v is num && (v as num) >= 0) ? '$v' : '—';
                                final isNarrow = MediaQuery.of(context).size.width < 400;
                                Widget buildItem(String label, String value, Color color) {
                                  final isNa = value == '—';
                                  final numberColor = isNa ? Colors.grey.shade600 : color;
                                  return isNarrow
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                label,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                              Text.rich(
                                                TextSpan(
                                                  children: [
                                                    TextSpan(
                                                      text: value,
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                        color: numberColor,
                                                      ),
                                                    ),
                                                  if (!isNa)
                                                    TextSpan(
                                                      text: ' 天',
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.grey[700],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : Column(
                                          children: [
                                            Text.rich(
                                              TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: value,
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                      color: numberColor,
                                                    ),
                                                  ),
                                                  if (!isNa)
                                                    TextSpan(
                                                      text: ' 天',
                                                      style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.grey[700],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        );
                                }
                                return Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: isNarrow
                                      ? Column(
                                          children: [
                                            buildItem(
                                                '最后两次间隔', formatInterval(lastTwo), Colors.purple.shade700),
                                            buildItem(
                                                '最后两次自动间隔', formatInterval(lastTwoAuto), Colors.blue.shade700),
                                            buildItem(
                                                '最后两次手动间隔', formatInterval(lastTwoManual), Colors.orange.shade700),
                                          ],
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                                          children: [
                                            buildItem(
                                                '最后两次间隔', formatInterval(lastTwo), Colors.purple.shade700),
                                            buildItem(
                                                '最后两次自动间隔', formatInterval(lastTwoAuto), Colors.blue.shade700),
                                            buildItem(
                                                '最后两次手动间隔', formatInterval(lastTwoManual), Colors.orange.shade700),
                                          ],
                                        ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _showRecordForm,
                                icon: const Icon(Icons.add),
                                label: const Text('记录'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              // 健康活动记录列表
                              if (_healthList.isNotEmpty) ...[
                        const Text(
                          '活动记录列表',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._healthList.map((item) {
                          final id = item['id'] as int;
                          final swipeX = _swipeX[id] ?? 0.0;
                          return GestureDetector(
                            onHorizontalDragStart: (details) => _touchStart(details, id),
                            onHorizontalDragUpdate: (details) => _touchMove(details, id),
                            onHorizontalDragEnd: (details) => _touchEnd(details, id),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.2),
                                    spreadRadius: 1,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // 删除按钮
                                  if (swipeX < 0)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 100,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.only(
                                            topRight: Radius.circular(8),
                                            bottomRight: Radius.circular(8),
                                          ),
                                        ),
                                        child: Center(
                                          child: TextButton(
                                            onPressed: _deleteDebounce.canExecute ? () => _deleteItem(id) : null,
                                            child: !_deleteDebounce.canExecute
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                    ),
                                                  )
                                                : const Text(
                                                    '删除',
                                                    style: TextStyle(color: Colors.white),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  // 内容
                                  Transform.translate(
                                    offset: Offset(swipeX, 0),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('日期：${item['record_date']}'),
                                          const SizedBox(height: 4),
                                          Text('时间：${item['record_time']}'),
                                          const SizedBox(height: 4),
                                          Text('持续时间：${item['duration']} 分钟'),
                                          const SizedBox(height: 4),
                                          Text('星期：${item['week_day']}'),
                                          const SizedBox(height: 4),
                                          _buildTagChip((item['tag'] ?? 'manual') == 'auto'),
                                          if (item['remark'] != null && item['remark'].toString().isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text('备注：${item['remark']}'),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                                }),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.all(32),
                                  child: const Center(
                                    child: Text(
                                      '暂无活动记录',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    ),
                    // 记录表单弹窗
                    if (_isRecordFormVisible)
                      Container(
                        color: Colors.black54,
                        child: Center(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // 桌面端限制最大宽度为600px
                              final maxWidth = constraints.maxWidth > 600 ? 600.0 : constraints.maxWidth;
                              return Container(
                                margin: const EdgeInsets.all(24),
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                constraints: BoxConstraints(maxWidth: maxWidth),
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                              const Text(
                                '记录健康活动',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              // 记录日期
                              Row(
                                children: [
                                  const Text('记录日期：'),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: _selectDate,
                                    child: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // 记录时间
                              Row(
                                children: [
                                  const Text('记录时间：'),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: _selectTime,
                                    child: Text('${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // 星期几
                              TextField(
                                controller: TextEditingController(
                                  text: _getWeekDay(_selectedDate),
                                ),
                                decoration: const InputDecoration(
                                  labelText: '星期几',
                                  border: OutlineInputBorder(),
                                ),
                                enabled: false,
                              ),
                              const SizedBox(height: 16),
                              // 持续时间
                              TextField(
                                controller: _durationController,
                                decoration: const InputDecoration(
                                  labelText: '持续时间（分钟）',
                                  border: OutlineInputBorder(),
                                  hintText: '请输入持续时间',
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: _onDurationInput,
                              ),
                              const SizedBox(height: 16),
                              // 标签选择（自动/手动）
                              Row(
                                children: [
                                  const Text('标签：'),
                                  const SizedBox(width: 16),
                                  ChoiceChip(
                                    label: const Text('手动'),
                                    selected: _recordTag == 'manual',
                                    selectedColor: Colors.orange.shade100,
                                    labelStyle: TextStyle(
                                      color: _recordTag == 'manual' ? Colors.orange.shade800 : null,
                                      fontWeight: _recordTag == 'manual' ? FontWeight.w600 : null,
                                    ),
                                    onSelected: (selected) {
                                      if (selected) setState(() => _recordTag = 'manual');
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  ChoiceChip(
                                    label: const Text('自动'),
                                    selected: _recordTag == 'auto',
                                    selectedColor: Colors.blue.shade100,
                                    labelStyle: TextStyle(
                                      color: _recordTag == 'auto' ? Colors.blue.shade800 : null,
                                      fontWeight: _recordTag == 'auto' ? FontWeight.w600 : null,
                                    ),
                                    onSelected: (selected) {
                                      if (selected) setState(() => _recordTag = 'auto');
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // 备注
                              TextField(
                                controller: _remarkController,
                                decoration: const InputDecoration(
                                  labelText: '备注',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: _onRemarkInput,
                              ),
                              const SizedBox(height: 24),
                              // 按钮
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _closeForm,
                                      child: const Text('取消'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _submitDebounce.canExecute ? _submitRecord : null,
                                      child: !_submitDebounce.canExecute
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Text('确定'),
                                    ),
                                  ),
                                ],
                              ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
