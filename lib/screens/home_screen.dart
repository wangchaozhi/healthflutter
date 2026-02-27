import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/music_player_service.dart';
import '../services/theme_service.dart';
import '../themes/app_themes.dart';
import '../utils/debounce.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppThemeColors get _colors =>
      Theme.of(context).extension<AppThemeColors>() ?? AppThemes.tealColors;

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
    final color = isAuto ? _colors.accentBlue : _colors.accentOrange;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4), width: 1),
          ),
          child: Text(
            isAuto ? '自动' : '手动',
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
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

  void _showThemePicker() {
    final themeService = ThemeService();
    showModalBottomSheet(
      context: context,
      backgroundColor: _colors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.palette_rounded, color: _colors.primary),
                  const SizedBox(width: 10),
                  Text('选择主题', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _colors.textPrimary)),
                ],
              ),
              const SizedBox(height: 20),
              ...AppThemeId.values.map((id) {
                final colors = AppThemes.colorsFor(id);
                final isSelected = themeService.themeId == id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        themeService.setTheme(id);
                        if (mounted) Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? colors.primary.withOpacity(0.12) : _colors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? colors.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(id.label, style: TextStyle(fontSize: 16, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: _colors.textPrimary)),
                            if (isSelected) ...[
                              const Spacer(),
                              Icon(Icons.check_circle_rounded, color: colors.primary, size: 22),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarBtn(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: _colors.textSecondary),
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }

  Widget _buildRecordMeta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: _colors.textSecondary),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 14, color: _colors.textSecondary)),
      ],
    );
  }

  Widget _buildNumberWithUnit(
    String number, {
    String? unit,
    required Color numberColor,
    double numberSize = 22,
    double unitSize = 20,
    FontWeight fontWeight = FontWeight.bold,
    TextAlign? textAlign,
  }) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: number,
            style: TextStyle(
              fontSize: numberSize,
              fontWeight: fontWeight,
              color: numberColor,
            ),
          ),
          if (unit != null && unit.isNotEmpty)
            TextSpan(
              text: unit,
              style: TextStyle(
                fontSize: unitSize,
                fontWeight: fontWeight,
                color: numberColor,
              ),
            ),
        ],
      ),
      textAlign: textAlign,
    );
  }

  Widget _buildStatChip(String label, String value, Color accent, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: accent),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: _colors.textSecondary)),
            _buildNumberWithUnit(
              value,
              unit: ' 次',
              numberColor: accent,
              numberSize: 22,
              unitSize: 20,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colors.surfaceLight,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _colors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.favorite_rounded, color: _colors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              '健康管理',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: _colors.textPrimary,
              ),
            ),
          ],
        ),
        backgroundColor: _colors.surfaceCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          _buildAppBarBtn(Icons.palette_outlined, '主题', _showThemePicker),
          _buildAppBarBtn(Icons.construction, '工具', () => Navigator.of(context).pushNamed('/tools_menu')),
          _buildAppBarBtn(Icons.public, 'WebView', () => Navigator.of(context).pushNamed('/webview_menu')),
          _buildAppBarBtn(Icons.music_note, '音乐', () => Navigator.of(context).pushNamed('/music_player')),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logoutDebounce.canExecute ? _handleLogout : null,
            tooltip: '退出登录',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _colors.primary),
                  const SizedBox(height: 16),
                  Text('加载中...', style: TextStyle(color: _colors.textSecondary, fontSize: 14)),
                ],
              ),
            )
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
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [_colors.primary.withOpacity(0.12), _colors.primaryLight.withOpacity(0.2)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _colors.primary.withOpacity(0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.schedule_rounded, color: _colors.primary, size: 24),
                                    const SizedBox(width: 12),
                                    Text(
                                      _currentDateTime,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: _colors.textPrimary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              // 健康活动记录容器
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: _colors.surfaceCard,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.analytics_rounded, color: _colors.primary, size: 26),
                                        const SizedBox(width: 10),
                                        Text(
                                          '健康活动记录',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            color: _colors.textPrimary,
                                          ),
                                        ),
                                      ],
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
                                    padding: const EdgeInsets.all(16),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [_colors.primary.withOpacity(0.1), _colors.primaryLight.withOpacity(0.15)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: _colors.primary.withOpacity(0.2), width: 1),
                                    ),
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '从 $earliest 至 $today 共计 ',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: _colors.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          TextSpan(
                                            text: '$total',
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: _colors.primary,
                                            ),
                                          ),
                                          TextSpan(
                                            text: ' 次',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: _colors.textSecondary,
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
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: _colors.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black.withOpacity(0.04)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStatChip('累计自动', '${_stats?['total_auto'] ?? 0}', _colors.accentBlue, Icons.auto_awesome),
                                  Container(width: 1, height: 32, color: Colors.black.withOpacity(0.06)),
                                  _buildStatChip('累计手动', '${_stats?['total_manual'] ?? 0}', _colors.accentOrange, Icons.touch_app),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: _colors.accentBlue.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _colors.accentBlue.withOpacity(0.2)),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildNumberWithUnit(
                                          '${_stats?['year_auto'] ?? 0}',
                                          unit: ' 次',
                                          numberColor: _colors.accentBlue,
                                          numberSize: 24,
                                          unitSize: 20,
                                        ),
                                        Text('今年自动', style: TextStyle(fontSize: 13, color: _colors.textSecondary)),
                                        const SizedBox(height: 10),
                                        _buildNumberWithUnit(
                                          '${_stats?['month_auto'] ?? 0}',
                                          unit: ' 次',
                                          numberColor: _colors.accentBlue,
                                          numberSize: 24,
                                          unitSize: 20,
                                        ),
                                        Text('本月自动', style: TextStyle(fontSize: 13, color: _colors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: _colors.accentOrange.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _colors.accentOrange.withOpacity(0.2)),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildNumberWithUnit(
                                          '${_stats?['year_manual'] ?? 0}',
                                          unit: ' 次',
                                          numberColor: _colors.accentOrange,
                                          numberSize: 24,
                                          unitSize: 20,
                                        ),
                                        Text('今年手动', style: TextStyle(fontSize: 13, color: _colors.textSecondary)),
                                        const SizedBox(height: 10),
                                        _buildNumberWithUnit(
                                          '${_stats?['month_manual'] ?? 0}',
                                          unit: ' 次',
                                          numberColor: _colors.accentOrange,
                                          numberSize: 24,
                                          unitSize: 20,
                                        ),
                                        Text('本月手动', style: TextStyle(fontSize: 13, color: _colors.textSecondary)),
                                      ],
                                    ),
                                  ),
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
                                  final numberColor = isNa ? _colors.textSecondary : color;
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
                                                  color: _colors.textSecondary,
                                                ),
                                              ),
                                              _buildNumberWithUnit(
                                                value,
                                                unit: isNa ? null : ' 天',
                                                numberColor: numberColor,
                                                numberSize: 18,
                                                unitSize: 18,
                                              ),
                                            ],
                                          ),
                                        )
                                      : Column(
                                          children: [
                                            _buildNumberWithUnit(
                                              value,
                                              unit: isNa ? null : ' 天',
                                              numberColor: numberColor,
                                              numberSize: 20,
                                              unitSize: 20,
                                            ),
                                            Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 13,
                                                        color: _colors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        );
                                }
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _colors.surfaceLight,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.black.withOpacity(0.04)),
                                  ),
                                  child: isNarrow
                                      ? Column(
                                          children: [
                                            buildItem(
                                                '最后两次间隔', formatInterval(lastTwo), _colors.primary),
                                            buildItem(
                                                '最后两次自动间隔', formatInterval(lastTwoAuto), _colors.accentBlue),
                                            buildItem(
                                                '最后两次手动间隔', formatInterval(lastTwoManual), _colors.accentOrange),
                                          ],
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                                          children: [
                                            buildItem(
                                                '最后两次间隔', formatInterval(lastTwo), _colors.primary),
                                            buildItem(
                                                '最后两次自动间隔', formatInterval(lastTwoAuto), _colors.accentBlue),
                                            buildItem(
                                                '最后两次手动间隔', formatInterval(lastTwoManual), _colors.accentOrange),
                                          ],
                                        ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _showRecordForm,
                                icon: const Icon(Icons.add_rounded, size: 22),
                                label: const Text('添加记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _colors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              // 健康活动记录列表
                              if (_healthList.isNotEmpty) ...[
                                    Row(
                                      children: [
                                        Icon(Icons.list_alt_rounded, color: _colors.primary, size: 22),
                                        const SizedBox(width: 8),
                                        Text(
                                          '活动记录列表',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: _colors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
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
                                color: _colors.surfaceCard,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(color: Colors.black.withOpacity(0.04)),
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
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: _colors.surfaceCard,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today_rounded, size: 18, color: _colors.primary),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${item['record_date']} ${item['record_time']}',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: _colors.textPrimary,
                                                ),
                                              ),
                                              const Spacer(),
                                              _buildTagChip((item['tag'] ?? 'manual') == 'auto'),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              _buildRecordMeta(Icons.timer_outlined, '${item['duration']} 分钟'),
                                              const SizedBox(width: 16),
                                              _buildRecordMeta(Icons.today_outlined, '${item['week_day']}'),
                                            ],
                                          ),
                                          if (item['remark'] != null && item['remark'].toString().isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              '${item['remark']}',
                                              style: TextStyle(fontSize: 13, color: _colors.textSecondary, fontStyle: FontStyle.italic),
                                            ),
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
                                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                                  decoration: BoxDecoration(
                                    color: _colors.surfaceCard,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 20,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.inbox_rounded, size: 64, color: _colors.textSecondary.withOpacity(0.4)),
                                      const SizedBox(height: 16),
                                      Text(
                                        '暂无活动记录',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: _colors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '点击上方「添加记录」开始记录',
                                        style: TextStyle(fontSize: 14, color: _colors.textSecondary.withOpacity(0.8)),
                                      ),
                                    ],
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
                        color: Colors.black.withOpacity(0.5),
                        child: Center(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // 桌面端限制最大宽度为600px
                              final maxWidth = constraints.maxWidth > 600 ? 600.0 : constraints.maxWidth;
                              return Container(
                                margin: const EdgeInsets.all(24),
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: _colors.surfaceCard,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 32,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                constraints: BoxConstraints(maxWidth: maxWidth),
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.edit_calendar_rounded, color: _colors.primary, size: 26),
                                          const SizedBox(width: 10),
                                          Text(
                                            '记录健康活动',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600,
                                              color: _colors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                              // 记录日期
                              InkWell(
                                onTap: _selectDate,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: _colors.surfaceLight,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.black.withOpacity(0.1)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_month_rounded, size: 22, color: _colors.primary),
                                      const SizedBox(width: 12),
                                      Text('记录日期', style: TextStyle(color: _colors.textSecondary, fontSize: 14)),
                                      const Spacer(),
                                      Text(
                                        DateFormat('yyyy-MM-dd').format(_selectedDate),
                                        style: TextStyle(fontWeight: FontWeight.w600, color: _colors.textPrimary),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.chevron_right, color: _colors.textSecondary, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // 记录时间
                              InkWell(
                                onTap: _selectTime,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: _colors.surfaceLight,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.black.withOpacity(0.1)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, size: 22, color: _colors.primary),
                                      const SizedBox(width: 12),
                                      Text('记录时间', style: TextStyle(color: _colors.textSecondary, fontSize: 14)),
                                      const Spacer(),
                                      Text(
                                        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(fontWeight: FontWeight.w600, color: _colors.textPrimary),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.chevron_right, color: _colors.textSecondary, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // 星期几
                              TextField(
                                controller: TextEditingController(
                                  text: _getWeekDay(_selectedDate),
                                ),
                                decoration: InputDecoration(
                                  labelText: '星期几',
                                  filled: true,
                                  fillColor: _colors.surfaceLight,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
                                  ),
                                ),
                                enabled: false,
                              ),
                              const SizedBox(height: 16),
                              // 持续时间
                              TextField(
                                controller: _durationController,
                                decoration: InputDecoration(
                                  labelText: '持续时间（分钟）',
                                  hintText: '请输入持续时间',
                                  filled: true,
                                  fillColor: _colors.surfaceLight,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: _colors.primary, width: 2),
                                  ),
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
                                    selectedColor: _colors.accentOrange.withOpacity(0.25),
                                    labelStyle: TextStyle(
                                      color: _recordTag == 'manual' ? _colors.accentOrange : _colors.textSecondary,
                                      fontWeight: _recordTag == 'manual' ? FontWeight.w600 : null,
                                    ),
                                    side: BorderSide(color: _recordTag == 'manual' ? _colors.accentOrange : Colors.black26),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    onSelected: (selected) {
                                      if (selected) setState(() => _recordTag = 'manual');
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  ChoiceChip(
                                    label: const Text('自动'),
                                    selected: _recordTag == 'auto',
                                    selectedColor: _colors.accentBlue.withOpacity(0.25),
                                    labelStyle: TextStyle(
                                      color: _recordTag == 'auto' ? _colors.accentBlue : _colors.textSecondary,
                                      fontWeight: _recordTag == 'auto' ? FontWeight.w600 : null,
                                    ),
                                    side: BorderSide(color: _recordTag == 'auto' ? _colors.accentBlue : Colors.black26),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                                decoration: InputDecoration(
                                  labelText: '备注',
                                  filled: true,
                                  fillColor: _colors.surfaceLight,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: _colors.primary, width: 2),
                                  ),
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
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        side: BorderSide(color: _colors.textSecondary.withOpacity(0.4)),
                                      ),
                                      child: Text('取消', style: TextStyle(color: _colors.textSecondary)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: _submitDebounce.canExecute ? _submitRecord : null,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _colors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: !_submitDebounce.canExecute
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Text('确定', style: TextStyle(fontWeight: FontWeight.w600)),
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
