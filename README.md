# HealthFlutter - 健康管理应用

基于 Flutter 和 Go 开发的跨平台健康管理应用，支持健康活动记录、音乐播放、文件管理等功能。

## 功能特性

### 核心功能
- **用户认证**: 注册、登录、JWT Token 认证
- **健康活动管理**: 记录、查看、删除健康活动，支持统计功能
- **音乐播放器**: 音乐上传、在线播放、播放列表管理、播放模式切换
- **歌词功能**: LRC 歌词上传、绑定、实时显示、滚动同步
- **文件传输**: 文件上传/下载、剪贴板同步
- **抖音解析**: 抖音视频链接解析和下载

### WebView 工具
- **AriaNg**: Aria2 下载管理界面
- **FileBrowser**: 文件浏览器（端口 6971）
- **XUI**: XUI 管理面板
- **FRPS**: FRP 服务管理

### 桌面功能
- **系统托盘**: Windows/Linux/macOS 系统托盘支持
- **窗口管理**: 最小化到托盘、窗口显示/隐藏

## 技术架构

### 前端 (Flutter)
- **框架**: Flutter 3.10.4+
- **状态管理**: StatefulWidget
- **网络请求**: http
- **本地存储**: shared_preferences
- **WebView**: webview_flutter
- **音频播放**: audioplayers
- **文件操作**: file_picker, path_provider

### 后端 (Go)
- **语言**: Go 1.21+
- **数据库**: SQLite (modernc.org/sqlite)
- **认证**: JWT (github.com/golang-jwt/jwt/v5)
- **密码加密**: bcrypt (golang.org/x/crypto/bcrypt)
- **HTTP 服务**: net/http

### 项目结构
```
healthflutter/
├── lib/                    # Flutter 前端
│   ├── config/            # 配置
│   ├── screens/           # 页面
│   ├── services/          # 服务层
│   ├── widgets/           # 组件
│   └── utils/             # 工具类
├── backend/               # Go 后端
│   ├── handlers/          # 请求处理
│   ├── database/          # 数据库操作
│   ├── models/            # 数据模型
│   ├── services/          # 业务服务
│   └── utils/             # 工具函数
└── assets/                # 资源文件
```

## 快速开始

### 启动后端
```bash
cd backend
go mod download
go run main.go
```
后端默认运行在 `http://localhost:8080`

### 运行前端
```bash
flutter pub get
flutter run
```

### 配置说明
编辑 `lib/config/api_config.dart` 配置 API 地址：
- Debug 模式：`http://192.168.31.252:8080/api`
- Release 模式：`http://107.182.17.20:8080/api`

## 构建发布

项目使用 GitHub Actions 自动构建多平台发布包：
- Android: APK
- iOS: IPA
- Windows: EXE
- macOS: DMG
- Linux: AppImage
- Web: 静态文件

## 许可证

MIT License
