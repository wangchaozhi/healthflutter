# HealthFlutter - 健康管理应用

一个基于 Flutter 和 Go 开发的健康活动记录管理应用，支持用户注册登录、健康活动记录、数据统计等功能。

## 项目简介

HealthFlutter 是一个跨平台健康管理应用，包含 Flutter 移动端和 Go 后端服务。用户可以记录日常健康活动（如运动、锻炼等），查看历史记录和统计信息。

## 技术栈

### 前端 (Flutter)
- **框架**: Flutter 3.10.4+
- **主要依赖**:
  - `http`: 用于 API 调用
  - `shared_preferences`: 本地存储（Token 保存）
  - `intl`: 日期时间格式化

### 后端 (Go)
- **语言**: Go 1.21+
- **数据库**: SQLite (使用 modernc.org/sqlite)
- **认证**: JWT (github.com/golang-jwt/jwt/v5)
- **密码加密**: bcrypt (golang.org/x/crypto/bcrypt)

## 功能特性

### 用户认证
- ✅ 用户注册
- ✅ 用户登录
- ✅ JWT Token 认证
- ✅ 用户信息查询

### 健康活动管理
- ✅ 创建健康活动记录（日期、时间、持续时间、备注）
- ✅ 查看活动记录列表（按日期倒序）
- ✅ 删除活动记录
- ✅ 活动统计（本年/本月总数）
- ✅ 自动计算星期几

### 音乐播放器 🎵 NEW!
- ✅ 音乐上传与管理
- ✅ 在线音乐播放
- ✅ 播放列表管理
- ✅ 播放模式（顺序/随机/单曲循环）
- ✅ 音乐搜索
- ✅ 音乐分享

### 歌词功能 🎤 NEW!
- ✅ LRC歌词上传
- ✅ 歌词与歌曲绑定
- ✅ 歌词搜索
- ✅ 实时歌词显示
- ✅ 歌词滚动同步
- ✅ 歌词管理

### 文件传输
- ✅ 文件上传/下载
- ✅ 文件管理
- ✅ 剪贴板同步

### 抖音视频解析
- ✅ 抖音视频链接解析
- ✅ 视频下载
- ✅ 视频管理

## 项目结构

```
healthflutter/
├── lib/                    # Flutter 前端代码
│   ├── config/            # 配置文件
│   │   └── api_config.dart  # API 配置
│   ├── screens/           # 页面
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   └── home_screen.dart
│   ├── services/          # 服务层
│   │   └── api_service.dart
│   └── main.dart          # 入口文件
├── backend/               # Go 后端代码
│   ├── main.go           # 主程序
│   ├── go.mod            # Go 依赖管理
│   └── health.db         # SQLite 数据库（自动生成）
└── README.md
```

## 快速开始

### 前置要求

1. **Flutter 环境**
   - Flutter SDK 3.10.4 或更高版本
   - Dart SDK
   - Android Studio / Xcode（用于移动端开发）

2. **Go 环境**
   - Go 1.21 或更高版本

### 安装步骤

#### 1. 克隆项目

```bash
git clone https://github.com/wangchaozhi/healthflutter.git
cd healthflutter
```

#### 2. 启动后端服务

```bash
cd backend
go mod download
go run main.go
```

后端服务默认运行在 `http://localhost:8080`

**注意**: 首次运行会自动创建 SQLite 数据库文件 `health.db` 和相关数据表。

#### 3. 配置前端 API 地址

编辑 `lib/config/api_config.dart`，根据你的运行环境修改 `baseUrl`:

```dart
// Android 模拟器
static const String baseUrl = 'http://10.0.2.2:8080/api';

// iOS 模拟器
static const String baseUrl = 'http://localhost:8080/api';

// 真机测试（替换为你的电脑IP地址）
static const String baseUrl = 'http://192.168.1.100:8080/api';
```

#### 4. 安装 Flutter 依赖并运行

```bash
flutter pub get
flutter run
```

## API 接口文档

### 基础 URL
```
http://localhost:8080/api
```

### 认证接口

#### 1. 用户注册
```
POST /api/register
Content-Type: application/json

Request Body:
{
  "username": "string",
  "password": "string"
}

Response:
{
  "success": true,
  "message": "注册成功",
  "token": "jwt_token_string",
  "user": {
    "id": 1,
    "username": "string"
  }
}
```

#### 2. 用户登录
```
POST /api/login
Content-Type: application/json

Request Body:
{
  "username": "string",
  "password": "string"
}

Response:
{
  "success": true,
  "message": "登录成功",
  "token": "jwt_token_string",
  "user": {
    "id": 1,
    "username": "string"
  }
}
```

#### 3. 获取用户信息
```
GET /api/profile
Authorization: Bearer {token}

Response:
{
  "success": true,
  "message": "获取成功",
  "user": {
    "id": 1,
    "username": "string"
  }
}
```

### 健康活动接口

#### 1. 创建活动记录
```
POST /api/activities
Authorization: Bearer {token}
Content-Type: application/json

Request Body:
{
  "record_date": "2024-01-01",    // 格式: YYYY-MM-DD
  "record_time": "14:30",         // 格式: HH:mm
  "duration": 60,                 // 持续时间（分钟）
  "remark": "慢跑"                // 备注（可选）
}

Response:
{
  "success": true,
  "message": "创建成功",
  "data": {
    "id": 1,
    "user_id": 1,
    "record_date": "2024-01-01",
    "record_time": "14:30",
    "week_day": "星期一",
    "duration": 60,
    "remark": "慢跑",
    "created_at": "2024-01-01 14:30:00"
  }
}
```

#### 2. 获取活动记录列表
```
GET /api/activities
Authorization: Bearer {token}

Response:
{
  "success": true,
  "message": "获取成功",
  "list": [
    {
      "id": 1,
      "user_id": 1,
      "record_date": "2024-01-01",
      "record_time": "14:30",
      "week_day": "星期一",
      "duration": 60,
      "remark": "慢跑",
      "created_at": "2024-01-01 14:30:00"
    }
  ]
}
```

#### 3. 删除活动记录
```
DELETE /api/activities/{id}
Authorization: Bearer {token}

Response:
{
  "success": true,
  "message": "删除成功"
}
```

#### 4. 获取活动统计
```
GET /api/activities/stats
Authorization: Bearer {token}

Response:
{
  "success": true,
  "message": "获取成功",
  "stats": {
    "year_count": 100,    // 本年总数
    "month_count": 10     // 本月总数
  }
}
```

## 数据库结构

### users 表
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键，自增 |
| username | TEXT | 用户名（唯一） |
| password | TEXT | 加密后的密码 |
| created_at | DATETIME | 创建时间 |

### health_activities 表
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键，自增 |
| user_id | INTEGER | 用户ID（外键） |
| record_date | TEXT | 记录日期（YYYY-MM-DD） |
| record_time | TEXT | 记录时间（HH:mm） |
| week_day | TEXT | 星期几 |
| duration | INTEGER | 持续时间（分钟） |
| remark | TEXT | 备注 |
| created_at | DATETIME | 创建时间 |

## 环境变量

### 后端
- `PORT`: 服务端口号（默认: 8080）

```bash
export PORT=8080
```

## 安全说明

⚠️ **重要**: 在生产环境中，请务必修改以下安全配置：

1. **JWT Secret**: 在 `backend/main.go` 中修改 `jwtSecret`
   ```go
   var jwtSecret = []byte("your-secret-key-change-in-production")
   ```

2. **CORS 配置**: 根据实际需求修改 CORS 设置，不要在生产环境中使用 `*`

3. **HTTPS**: 生产环境建议使用 HTTPS

## 开发说明

### 后端开发
```bash
cd backend
go run main.go
```

### Flutter 开发
```bash
# 获取依赖
flutter pub get

# 运行应用
flutter run

# 构建 APK (Android)
flutter build apk

# 构建 IPA (iOS)
flutter build ios
```

## 许可证

本项目采用 MIT 许可证。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 作者

- GitHub: [wangchaozhi](https://github.com/wangchaozhi)

## 更新日志

### v2.0.0 (2025-12-21)
- ✨ **新增**: 完整的歌词功能
  - 支持LRC歌词上传和管理
  - 实时歌词显示与滚动同步
  - 歌词搜索和绑定功能
  - 详见 [歌词功能指南](LYRICS_GUIDE.md)
- 🎵 优化: 音乐播放器UI和功能
- 📚 新增: 详细的功能文档

### v1.5.0
- ✨ 新增: 音乐播放器功能
- ✨ 新增: 音乐分享功能
- ✨ 新增: 文件传输功能
- ✨ 新增: 抖音视频解析功能

### v1.0.0
- ✅ 用户注册/登录功能
- ✅ JWT 认证
- ✅ 健康活动记录 CRUD
- ✅ 活动统计功能
- ✅ Flutter 移动端界面

## 歌词功能快速开始 🎤

想要快速体验歌词功能？查看我们的指南：

- 📖 [歌词功能使用指南](LYRICS_GUIDE.md) - 完整的使用说明和API文档
- 🚀 [快速入门指南](LYRICS_QUICKSTART.md) - 5分钟快速上手
- 💻 [实现文档](LYRICS_IMPLEMENTATION.md) - 技术实现细节
- 📋 [变更清单](LYRICS_CHANGES.md) - 所有文件变更记录

### 示例歌词文件

项目包含了一个示例歌词文件 `example_lyrics.lrc`，可以用于测试歌词功能。
