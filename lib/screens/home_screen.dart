import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _userInfo;
  bool _isLoading = true;
  List<dynamic> _healthList = [];
  Map<String, dynamic>? _stats;
  bool _isRecordFormVisible = false;
  String _currentDateTime = '';
  
  // 表单数据
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _duration = 0;
  String _remark = '';
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  
  // 滑动删除相关
  Map<int, double> _swipeX = {};

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
      _loadUserInfo(),
      _loadActivities(),
      _loadStats(),
    ]);
  }

  Future<void> _loadUserInfo() async {
    final result = await ApiService.getProfile();
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _userInfo = result['user'];
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
          return;
        }
      });
    }
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
    setState(() {
      _isRecordFormVisible = true;
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
      _duration = 0;
      _remark = '';
      _durationController.clear();
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

    final recordDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final recordTime = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    final result = await ApiService.createActivity(
      recordDate: recordDate,
      recordTime: recordTime,
      duration: _duration,
      remark: _remark,
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
  }

  Future<void> _deleteItem(int id) async {
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
    setState(() {
      _swipeX.remove(id);
    });
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
    await ApiService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('健康管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: '退出登录',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      '${_stats?['year_count'] ?? 0}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const Text('今年总活动次数'),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '${_stats?['month_count'] ?? 0}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const Text('本月活动次数'),
                                  ],
                                ),
                              ],
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
                                            onPressed: () => _deleteItem(id),
                                            child: const Text(
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
                        }).toList(),
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
                // 记录表单弹窗
                if (_isRecordFormVisible)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
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
                                    child: ElevatedButton(
                                      onPressed: _submitRecord,
                                      child: const Text('确定'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _closeForm,
                                      child: const Text('取消'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
