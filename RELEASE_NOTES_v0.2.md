# v0.2 - Music Player and Sharing Features

## 🎵 新功能

### 音乐播放器
- ✅ 音乐上传：支持上传音频文件
- ✅ 音乐列表：查看和管理已上传的音乐
- ✅ 音乐播放：支持流式播放音频
- ✅ 音乐删除：删除不需要的音乐文件

### 音乐分享
- ✅ 分享链接：生成音乐分享链接
- ✅ 公开播放器：支持通过链接公开播放音乐
- ✅ 分享管理：查看和管理分享的音乐

### 代码优化
- ✅ 认证重构：将认证代码模块化到 `auth.go`
- ✅ 文件传输优化：添加上传/下载进度跟踪
- ✅ 日期时间格式优化：更友好的显示格式

## 📦 技术更新

- 添加 `audioplayers` 依赖用于音频播放
- 新增音乐数据库操作 (`music_db.go`, `music_share_db.go`)
- 新增音乐处理路由和处理器
- 更新 CORS 配置支持 Range 请求（音频流式播放）
- Android 支持 HTTP 明文流量（开发环境）

## 🔗 相关提交

- `feat: add music player functionality and refactor auth code`
- `feat: add music sharing functionality`
