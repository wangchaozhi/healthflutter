import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity.dart';
import '../services/activity_store.dart';
import '../services/auth_repository.dart';
import '../services/music_player_service.dart';
import '../services/theme_service.dart';
import '../themes/app_themes.dart';
import '../utils/debounce.dart';
import '../widgets/health/activity_list.dart';
import '../widgets/health/date_time_banner.dart';
import '../widgets/health/record_form_sheet.dart';
import '../widgets/health/stats_card.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppThemeColors get _colors =>
      Theme.of(context).extension<AppThemeColors>() ?? AppThemes.tealColors;

  final ActivityStore _store = ActivityStore.instance;
  Timer? _clockTimer;
  bool _isRecordFormVisible = false;
  String _currentDateTime = '';

  // 防抖相关
  final DebounceState _submitDebounce = DebounceState();
  final DebounceState _deleteDebounce = DebounceState();
  final DebounceState _logoutDebounce = DebounceState();

  @override
  void initState() {
    super.initState();
    _updateDateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateDateTime();
    });
    _store.refresh();
  }

  void _updateDateTime() {
    setState(() {
      _currentDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    });
  }

  Future<void> _refresh() => _store.refresh();

  void _showRecordForm() {
    if (!Debounce.debounceTime(delay: 500)) return;
    setState(() => _isRecordFormVisible = true);
  }

  void _closeForm() {
    setState(() => _isRecordFormVisible = false);
  }

  Future<void> _handleFormSubmit({
    required DateTime date,
    required TimeOfDay time,
    required int duration,
    required String remark,
    required ActivityTag tag,
  }) async {
    await _submitDebounce.execute(
      action: () async {
        final recordDate = DateFormat('yyyy-MM-dd').format(date);
        final recordTime =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

        final error = await _store.create(
          recordDate: recordDate,
          recordTime: recordTime,
          duration: duration,
          remark: remark,
          tag: tag,
        );

        if (!mounted) return;
        if (error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('记录成功')),
          );
          _closeForm();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
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
        final error = await _store.delete(id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? '删除成功')),
        );
      },
      onStart: () {
        if (mounted) setState(() {});
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _handleLogout() async {
    await _logoutDebounce.execute(
      action: () async {
        // 停止并重置播放器
        final playerService = MusicPlayerService();
        await playerService.stopAndReset();
        
        // 退出登录
        await AuthRepository.instance.logout();
        _store.clear();
        
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
    _clockTimer?.cancel();
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
                          color: isSelected ? colors.primary.withValues(alpha: 0.12) : _colors.surfaceLight,
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
                color: _colors.primary.withValues(alpha: 0.15),
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
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          if (_store.isLoading && _store.activities.isEmpty && _store.stats == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _colors.primary),
                  const SizedBox(height: 16),
                  Text('加载中...', style: TextStyle(color: _colors.textSecondary, fontSize: 14)),
                ],
              ),
            );
          }
          return LayoutBuilder(
              builder: (context, constraints) {
                // 桌面端限制最大宽度为1200px
                final maxWidth = constraints.maxWidth > 1200 ? 1200.0 : constraints.maxWidth;
                return Stack(
                  children: [
                    Center(
                      child: RefreshIndicator(
                        onRefresh: _refresh,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16.0),
                          child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DateTimeBanner(text: _currentDateTime, colors: _colors),
                              const SizedBox(height: 24),
                              StatsCard(
                                stats: _store.stats,
                                colors: _colors,
                                onAddPressed: _showRecordForm,
                              ),
                              const SizedBox(height: 24),
                              ActivityList(
                                activities: _store.activities,
                                colors: _colors,
                                canDelete: _deleteDebounce.canExecute,
                                onDelete: _deleteItem,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ),
                    if (_isRecordFormVisible)
                      RecordFormSheet(
                        colors: _colors,
                        submitting: !_submitDebounce.canExecute,
                        onClose: _closeForm,
                        onSubmit: _handleFormSubmit,
                      ),
                  ],
                );
              },
            );
        },
      ),
    );
  }
}
