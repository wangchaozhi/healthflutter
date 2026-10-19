import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../themes/app_themes.dart';

class DateTimeBanner extends StatefulWidget {
  const DateTimeBanner({super.key, required this.colors});

  final AppThemeColors colors;

  @override
  State<DateTimeBanner> createState() => _DateTimeBannerState();
}

class _DateTimeBannerState extends State<DateTimeBanner> {
  late String _text;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _text = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    if (!mounted) return;
    setState(() {
      _text = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withValues(alpha: 0.12),
            colors.primaryLight.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule_rounded, color: colors.primary, size: 24),
          const SizedBox(width: 12),
          Text(
            _text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
