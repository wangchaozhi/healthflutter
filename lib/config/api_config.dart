class ApiConfig {
  // 开发环境：使用 localhost 或实际IP地址
  // Android 模拟器使用: http://10.0.2.2:8080
  // iOS 模拟器使用: http://localhost:8080
  // 真机测试使用: http://你的电脑IP:8080
  static const String baseUrl = 'http://192.168.31.252:8080/api';
  // static const String baseUrl = 'http://107.182.17.20:8080/api';
  
  // 如果需要切换环境，可以修改这里
  // static const String baseUrl = 'http://10.0.2.2:8080/api'; // Android模拟器
  // static const String baseUrl = 'http://192.168.1.100:8080/api'; // 真机测试（替换为你的IP）
}

