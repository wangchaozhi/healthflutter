import 'package:flutter/material.dart';

class ToolsMenuItem {
  final String title;
  final String description;
  final IconData icon;
  final String route;
  final Color color;

  const ToolsMenuItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
    required this.color,
  });
}

class ToolsMenuScreen extends StatelessWidget {
  const ToolsMenuScreen({super.key});

  // 定义所有工具子页面
  static const List<ToolsMenuItem> _menuItems = [
    ToolsMenuItem(
      title: '抖音解析工具',
      description: '解析抖音视频链接',
      icon: Icons.video_library,
      route: '/douyin',
      color: Colors.red,
    ),
    ToolsMenuItem(
      title: '文件传输',
      description: '上传和管理文件',
      icon: Icons.file_upload,
      route: '/file_transfer',
      color: Colors.blue,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('工具'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _menuItems.length,
        itemBuilder: (context, index) {
          final item = _menuItems[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: InkWell(
              onTap: () {
                Navigator.of(context).pushNamed(item.route);
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item.icon,
                        color: item.color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
