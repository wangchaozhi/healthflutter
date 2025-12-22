import 'package:flutter/material.dart';

class WebViewMenuItem {
  final String title;
  final String description;
  final IconData icon;
  final String route;
  final Color color;

  const WebViewMenuItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
    required this.color,
  });
}

class WebViewMenuScreen extends StatelessWidget {
  const WebViewMenuScreen({super.key});

  // 定义所有 webview 子页面
  static const List<WebViewMenuItem> _menuItems = [
    WebViewMenuItem(
      title: 'AriaNg 下载管理',
      description: 'Aria2 下载管理界面',
      icon: Icons.download,
      route: '/ariang',
      color: Colors.blue,
    ),
    WebViewMenuItem(
      title: '文件浏览器',
      description: '文件浏览和管理',
      icon: Icons.folder,
      route: '/filebrowser',
      color: Colors.green,
    ),
    WebViewMenuItem(
      title: 'X-UI 管理',
      description: 'X-UI 代理管理界面',
      icon: Icons.vpn_key,
      route: '/xui',
      color: Colors.orange,
    ),
    WebViewMenuItem(
      title: 'FRPS 管理',
      description: 'FRP 服务端管理界面',
      icon: Icons.cloud,
      route: '/frps',
      color: Colors.purple,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebView 服务'),
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
