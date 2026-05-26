import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/activity.dart';
import '../../themes/app_themes.dart';

typedef RecordFormSubmit = Future<void> Function({
  required DateTime date,
  required TimeOfDay time,
  required int duration,
  required String remark,
  required ActivityTag tag,
});

class RecordFormSheet extends StatefulWidget {
  const RecordFormSheet({
    super.key,
    required this.colors,
    required this.submitting,
    required this.onSubmit,
    required this.onClose,
  });

  final AppThemeColors colors;
  final bool submitting;
  final RecordFormSubmit onSubmit;
  final VoidCallback onClose;

  @override
  State<RecordFormSheet> createState() => _RecordFormSheetState();
}

class _RecordFormSheetState extends State<RecordFormSheet> {
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  int _duration = 1;
  String _remark = '';
  ActivityTag _tag = ActivityTag.manual;
  final TextEditingController _durationController = TextEditingController(text: '1');
  final TextEditingController _remarkController = TextEditingController();

  @override
  void dispose() {
    _durationController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  String _getWeekDay(DateTime d) {
    const weekdays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
    return weekdays[d.weekday % 7];
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _date) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && picked != _time) {
      setState(() => _time = picked);
    }
  }

  Future<void> _submit() async {
    if (_duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入持续时间')),
      );
      return;
    }
    await widget.onSubmit(
      date: _date,
      time: _time,
      duration: _duration,
      remark: _remark,
      tag: _tag,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth > 600 ? 600.0 : constraints.maxWidth;
            return Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colors.surfaceCard,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
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
                        Icon(Icons.edit_calendar_rounded, color: colors.primary, size: 26),
                        const SizedBox(width: 10),
                        Text('记录健康活动', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _RowField(
                      colors: colors,
                      icon: Icons.calendar_month_rounded,
                      label: '记录日期',
                      value: DateFormat('yyyy-MM-dd').format(_date),
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 16),
                    _RowField(
                      colors: colors,
                      icon: Icons.access_time_rounded,
                      label: '记录时间',
                      value: '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                      onTap: _pickTime,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: TextEditingController(text: _getWeekDay(_date)),
                      decoration: InputDecoration(
                        labelText: '星期几',
                        filled: true,
                        fillColor: colors.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                        ),
                      ),
                      enabled: false,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _durationController,
                      decoration: InputDecoration(
                        labelText: '持续时间（分钟）',
                        hintText: '请输入持续时间',
                        filled: true,
                        fillColor: colors.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colors.primary, width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => setState(() => _duration = int.tryParse(v) ?? 0),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('标签：'),
                        const SizedBox(width: 16),
                        _TagChip(
                          label: '手动',
                          selected: _tag == ActivityTag.manual,
                          accent: colors.accentOrange,
                          onSelected: () => setState(() => _tag = ActivityTag.manual),
                        ),
                        const SizedBox(width: 12),
                        _TagChip(
                          label: '自动',
                          selected: _tag == ActivityTag.auto,
                          accent: colors.accentBlue,
                          onSelected: () => setState(() => _tag = ActivityTag.auto),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _remarkController,
                      decoration: InputDecoration(
                        labelText: '备注',
                        filled: true,
                        fillColor: colors.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colors.primary, width: 2),
                        ),
                      ),
                      onChanged: (v) => _remark = v,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: widget.onClose,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: colors.textSecondary.withValues(alpha: 0.4)),
                            ),
                            child: Text('取消', style: TextStyle(color: colors.textSecondary)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: widget.submitting ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: widget.submitting
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
    );
  }
}

class _RowField extends StatelessWidget {
  const _RowField({
    required this.colors,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final AppThemeColors colors;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colors.primary),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 14)),
            const Spacer(),
            Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: colors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: accent.withValues(alpha: 0.25),
      labelStyle: TextStyle(
        color: accent,
        fontWeight: selected ? FontWeight.w600 : null,
      ),
      side: BorderSide(color: selected ? accent : accent.withValues(alpha: 0.45)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (s) {
        if (s) onSelected();
      },
    );
  }
}
