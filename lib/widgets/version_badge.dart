import 'package:flutter/material.dart';

import '../services/app_info_service.dart';

class VersionBadge extends StatelessWidget {
  const VersionBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder(
      future: AppInfoService.info,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final version = snapshot.data!.version;
        return Semantics(
          label: '应用版本 $version',
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 9,
              vertical: compact ? 2 : 4,
            ),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Text(
              'v$version',
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: compact ? 10 : 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        );
      },
    );
  }
}
