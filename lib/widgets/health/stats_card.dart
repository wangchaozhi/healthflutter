import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/activity_stats.dart';
import '../../themes/app_themes.dart';

class StatsCard extends StatelessWidget {
  const StatsCard({
    super.key,
    required this.stats,
    required this.colors,
    required this.onAddPressed,
  });

  final ActivityStats? stats;
  final AppThemeColors colors;
  final VoidCallback onAddPressed;

  String _formatStat(num? value) {
    if (value == null || value < 0) return '—';
    final days = value.toDouble();
    final text = days.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
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
            style: TextStyle(fontSize: numberSize, fontWeight: fontWeight, color: numberColor),
          ),
          if (unit != null && unit.isNotEmpty)
            TextSpan(
              text: unit,
              style: TextStyle(fontSize: unitSize, fontWeight: fontWeight, color: numberColor),
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
            Text(label, style: TextStyle(fontSize: 13, color: colors.textSecondary)),
            _buildNumberWithUnit(value, unit: ' 次', numberColor: accent, numberSize: 22, unitSize: 20),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final earliest = stats?.earliestDate;
    final total = (stats?.totalAuto ?? 0) + (stats?.totalManual ?? 0);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final s = stats;
    final lastTwo = _formatStat(s?.lastIntervalDays ?? (s != null && s.lastTwoInterval >= 0 ? s.lastTwoInterval : null));
    final lastTwoAuto = _formatStat(s?.lastAutoIntervalDays ?? (s != null && s.lastTwoAutoInterval >= 0 ? s.lastTwoAutoInterval : null));
    final lastTwoManual = _formatStat(s?.lastManualIntervalDays ?? (s != null && s.lastTwoManualInterval >= 0 ? s.lastTwoManualInterval : null));
    final lastToNow = _formatStat(s?.lastToNowDays);

    final isNarrow = MediaQuery.of(context).size.width < 400;

    Widget buildIntervalItem(String label, String value, Color color) {
      final isNa = value == '—';
      final numberColor = isNa ? colors.textSecondary : color;
      return isNarrow
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: TextStyle(fontSize: 14, color: colors.textSecondary)),
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
                Text(label, style: TextStyle(fontSize: 13, color: colors.textSecondary)),
              ],
            );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: colors.primary, size: 26),
              const SizedBox(width: 10),
              Text(
                '健康活动记录',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (earliest != null && earliest.isNotEmpty && total > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary.withValues(alpha: 0.1), colors.primaryLight.withValues(alpha: 0.15)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.primary.withValues(alpha: 0.2), width: 1),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '从 $earliest 至 $today 共计 ',
                      style: TextStyle(fontSize: 15, color: colors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                    TextSpan(
                      text: '$total',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colors.primary),
                    ),
                    TextSpan(
                      text: ' 次',
                      style: TextStyle(fontSize: 15, color: colors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatChip('累计手动', '${stats?.totalManual ?? 0}', colors.accentOrange, Icons.touch_app),
                Container(width: 1, height: 32, color: Colors.black.withValues(alpha: 0.06)),
                _buildStatChip('累计自动', '${stats?.totalAuto ?? 0}', colors.accentBlue, Icons.auto_awesome),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildNumberWithUnit(
                    _formatStat(stats?.manualPeriodDays),
                    unit: ' 天/次',
                    numberColor: colors.accentOrange,
                    numberSize: 18,
                    unitSize: 14,
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: _buildNumberWithUnit(
                    _formatStat(stats?.autoPeriodDays),
                    unit: ' 天/次',
                    numberColor: colors.accentBlue,
                    numberSize: 18,
                    unitSize: 14,
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: _buildNumberWithUnit(
                    _formatStat(stats?.totalPeriodDays),
                    unit: ' 天/次',
                    numberColor: colors.primary,
                    numberSize: 18,
                    unitSize: 14,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text('手动周期', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                ),
                Expanded(
                  child: Text('自动周期', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                ),
                Expanded(
                  child: Text('总周期', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                ),
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
                    color: colors.accentOrange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.accentOrange.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      _buildNumberWithUnit('${stats?.yearManual ?? 0}', unit: ' 次', numberColor: colors.accentOrange, numberSize: 24, unitSize: 20),
                      Text('今年手动', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                      const SizedBox(height: 10),
                      _buildNumberWithUnit('${stats?.monthManual ?? 0}', unit: ' 次', numberColor: colors.accentOrange, numberSize: 24, unitSize: 20),
                      Text('本月手动', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.accentBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.accentBlue.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      _buildNumberWithUnit('${stats?.yearAuto ?? 0}', unit: ' 次', numberColor: colors.accentBlue, numberSize: 24, unitSize: 20),
                      Text('今年自动', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                      const SizedBox(height: 10),
                      _buildNumberWithUnit('${stats?.monthAuto ?? 0}', unit: ' 次', numberColor: colors.accentBlue, numberSize: 24, unitSize: 20),
                      Text('本月自动', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            ),
            child: isNarrow
                ? Column(
                    children: [
                      buildIntervalItem('最后一次距今', lastToNow, colors.primaryLight),
                      buildIntervalItem('最后两次间隔', lastTwo, colors.primary),
                      buildIntervalItem('最后两次手动间隔', lastTwoManual, colors.accentOrange),
                      buildIntervalItem('最后两次自动间隔', lastTwoAuto, colors.accentBlue),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: buildIntervalItem('最后一次距今', lastToNow, colors.primaryLight)),
                          Expanded(child: buildIntervalItem('最后两次间隔', lastTwo, colors.primary)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: buildIntervalItem('最后两次手动间隔', lastTwoManual, colors.accentOrange)),
                          Expanded(child: buildIntervalItem('最后两次自动间隔', lastTwoAuto, colors.accentBlue)),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add_rounded, size: 22),
              label: const Text('添加记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
