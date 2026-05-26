import 'package:flutter/material.dart';
import '../../models/activity.dart';
import '../../themes/app_themes.dart';

class ActivityList extends StatefulWidget {
  const ActivityList({
    super.key,
    required this.activities,
    required this.colors,
    required this.canDelete,
    required this.onDelete,
  });

  final List<Activity> activities;
  final AppThemeColors colors;
  final bool canDelete;
  final Future<void> Function(int id) onDelete;

  @override
  State<ActivityList> createState() => _ActivityListState();
}

class _ActivityListState extends State<ActivityList> {
  final Map<int, double> _swipeX = {};

  void _onDragStart(int id) {
    setState(() => _swipeX[id] = 0);
  }

  void _onDragUpdate(int id, double dx) {
    setState(() {
      final newX = (_swipeX[id] ?? 0) + dx;
      _swipeX[id] = newX.clamp(-100.0, 0.0);
    });
  }

  void _onDragEnd(int id) {
    setState(() {
      _swipeX[id] = (_swipeX[id] ?? 0) < -50 ? -100.0 : 0.0;
    });
  }

  Future<void> _handleDelete(int id) async {
    await widget.onDelete(id);
    if (!mounted) return;
    setState(() => _swipeX.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    if (widget.activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: colors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('暂无活动记录', style: TextStyle(fontSize: 16, color: colors.textSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('点击上方「添加记录」开始记录',
                style: TextStyle(fontSize: 14, color: colors.textSecondary.withValues(alpha: 0.8))),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.list_alt_rounded, color: colors.primary, size: 22),
            const SizedBox(width: 8),
            Text('活动记录列表',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.textPrimary)),
          ],
        ),
        const SizedBox(height: 14),
        ...widget.activities.map((item) {
          final id = item.id;
          final swipeX = _swipeX[id] ?? 0.0;
          return GestureDetector(
            onHorizontalDragStart: (_) => _onDragStart(id),
            onHorizontalDragUpdate: (d) => _onDragUpdate(id, d.delta.dx),
            onHorizontalDragEnd: (_) => _onDragEnd(id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
              ),
              child: Stack(
                children: [
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
                            onPressed: widget.canDelete ? () => _handleDelete(id) : null,
                            child: !widget.canDelete
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('删除', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                  Transform.translate(
                    offset: Offset(swipeX, 0),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colors.surfaceCard,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 18, color: colors.primary),
                              const SizedBox(width: 8),
                              Text(
                                '${item.recordDate} ${item.recordTime}',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary),
                              ),
                              const Spacer(),
                              _TagChip(isAuto: item.isAuto, colors: colors),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _Meta(icon: Icons.timer_outlined, text: '${item.duration} 分钟', colors: colors),
                              const SizedBox(width: 16),
                              _Meta(icon: Icons.today_outlined, text: item.weekDay, colors: colors),
                            ],
                          ),
                          if (item.remark.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              item.remark,
                              style: TextStyle(fontSize: 13, color: colors.textSecondary, fontStyle: FontStyle.italic),
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
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.isAuto, required this.colors});

  final bool isAuto;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    final color = isAuto ? colors.accentBlue : colors.accentOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        isAuto ? '自动' : '手动',
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, required this.colors});

  final IconData icon;
  final String text;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colors.textSecondary),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 14, color: colors.textSecondary)),
      ],
    );
  }
}
