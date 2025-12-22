import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/api_config.dart';
import '../utils/platform_utils.dart';
import 'package:webview_flutter/webview_flutter.dart';

class FrpsScreen extends StatefulWidget {
  const FrpsScreen({super.key});

  @override
  State<FrpsScreen> createState() => _FrpsScreenState();
}

class _FrpsScreenState extends State<FrpsScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _errorMessage;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
  }

  String get _frpsUrl {
    // 从 API 配置中获取基础 URL，提取 IP 地址，使用 7600 端口
    final baseUrl = ApiConfig.baseUrl;
    final uri = Uri.parse(baseUrl);
    // 构建 frps URL：使用相同的 IP，但端口改为 7600
    return '${uri.scheme}://${uri.host}:7600';
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // 返回上一页
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开浏览器: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Web 平台和桌面平台使用外部浏览器（webview_flutter 不支持 Windows/Linux）
    if (kIsWeb || isDesktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openInBrowser(_frpsUrl);
      });
      return Scaffold(
        appBar: AppBar(
          title: const Text('FRPS 管理'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在打开浏览器...'),
            ],
          ),
        ),
      );
    }

    // Android/iOS 平台使用 WebView
    if (_controller == null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
                _loadingProgress = 0;
              });
            },
            onPageFinished: (String url) {
              setState(() {
                _isLoading = false;
              });
            },
            onProgress: (int progress) {
              setState(() {
                _loadingProgress = progress;
              });
            },
            onWebResourceError: (WebResourceError error) {
              setState(() {
                _isLoading = false;
                _errorMessage = '加载失败: ${error.description}';
              });
            },
          ),
        )
        ..loadRequest(Uri.parse(_frpsUrl));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('FRPS 管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller?.reload();
            },
            tooltip: '刷新',
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller!),
          if (_isLoading && _loadingProgress < 100)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _loadingProgress / 100,
                backgroundColor: Colors.grey[300],
              ),
            ),
          if (_errorMessage != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _controller?.reload();
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
