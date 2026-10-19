import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_info_service.dart';
import '../themes/app_themes.dart';
import '../widgets/version_badge.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static final Uri _repositoryUri = Uri.parse(
    'https://github.com/wangchaozhi/healthflutter',
  );
  static final Uri _releasesUri = Uri.parse(
    'https://github.com/wangchaozhi/healthflutter/releases',
  );

  Future<void> _openUrl(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法打开链接')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppThemeColors>() ?? AppThemes.tealColors;
    return Scaffold(
      backgroundColor: colors.surfaceLight,
      appBar: AppBar(
        title: const Text('关于'),
        backgroundColor: colors.surfaceCard,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder(
        future: AppInfoService.info,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: colors.primary),
            );
          }
          final info = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Icon(
                          Icons.favorite_rounded,
                          color: colors.primary,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '健康管理',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const VersionBadge(),
                      const SizedBox(height: 12),
                      Text(
                        '记录健康活动，管理常用工具与个人音乐。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _InfoCard(
                        colors: colors,
                        children: [
                          _InfoRow(label: '版本', value: info.version),
                          _InfoRow(label: '构建号', value: info.buildNumber),
                          _InfoRow(label: '应用标识', value: info.packageName),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InfoCard(
                        colors: colors,
                        children: [
                          _LinkRow(
                            icon: Icons.code_rounded,
                            label: '项目主页',
                            onTap: () => _openUrl(context, _repositoryUri),
                          ),
                          _LinkRow(
                            icon: Icons.new_releases_outlined,
                            label: '版本发布',
                            onTap: () => _openUrl(context, _releasesUri),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '© ${DateTime.now().year} 健康管理',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.colors, required this.children});

  final AppThemeColors colors;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surfaceCard,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.textSecondary.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: List.generate(children.length * 2 - 1, (index) {
          if (index.isEven) return children[index ~/ 2];
          return Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: colors.textSecondary.withValues(alpha: 0.12),
          );
        }),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Text(
          value,
          textAlign: TextAlign.end,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
      onTap: onTap,
    );
  }
}
