# 歌词功能使用说明

## 功能概述

本项目已集成完整的歌词功能，支持：
1. ✅ 歌词文件上传（支持 .lrc 和 .txt 格式）
2. ✅ 歌词与歌曲绑定
3. ✅ 歌词搜索
4. ✅ 实时歌词显示（滚动同步）
5. ✅ 歌词管理（编辑绑定、删除）

## 使用方法

### 1. 上传歌词

有两种方式上传歌词：

#### 方式一：播放时直接上传并绑定
1. 播放一首歌曲
2. 点击播放器控制栏的"歌词"按钮（♪图标）
3. 点击"管理歌词"按钮（笔记本图标）
4. 在弹出的对话框中点击"上传"按钮
5. 选择 .lrc 或 .txt 格式的歌词文件
6. 上传后会自动绑定到当前歌曲

#### 方式二：先上传后绑定
1. 通过API上传歌词文件（不指定music_id）
2. 播放歌曲时，点击"管理歌词"按钮
3. 在歌词列表中选择对应的歌词，点击"绑定"按钮

### 2. 查看歌词

1. 播放已绑定歌词的歌曲
2. 点击播放器控制栏的"歌词"按钮（♪图标）
3. 歌词会以滚动方式显示，当前播放行会高亮显示
4. 歌词会自动跟随播放进度滚动

### 3. 搜索歌词

1. 点击"管理歌词"按钮
2. 在搜索框中输入歌曲名称或艺术家
3. 点击"搜索"或按Enter键
4. 系统会显示匹配的歌词列表

### 4. 管理歌词

- **查看歌词**：点击歌词按钮切换显示/隐藏
- **绑定歌词**：在歌词管理对话框中选择歌词并点击"绑定"
- **删除歌词**：通过API调用删除（前端可扩展）

## LRC歌词格式说明

LRC是一种常用的歌词格式，格式如下：

```
[00:12.00]第一行歌词
[00:17.20]第二行歌词
[00:21.10]第三行歌词
```

时间标签格式：`[mm:ss.xx]`
- mm：分钟（2位数字）
- ss：秒钟（2位数字）
- xx：毫秒（2-3位数字）

### 示例歌词文件

创建一个名为 `example.lrc` 的文件：

```lrc
[00:00.00]歌曲名称 - 艺术家
[00:05.00]
[00:12.50]天空中飘着云朵
[00:17.80]心中满是期待
[00:23.10]梦想在远方召唤
[00:28.40]勇敢向前迈步
[00:33.70]
[00:35.00]副歌部分：
[00:38.20]让我们一起歌唱
[00:43.50]让世界充满希望
[00:48.80]用音乐连接彼此
[00:54.10]创造美好时光
```

## API接口说明

### 上传歌词
```
POST /api/lyrics/upload
Headers: Authorization: Bearer <token>
Content-Type: multipart/form-data

Body:
- file: 歌词文件（.lrc或.txt）
- title: 歌曲标题（可选）
- artist: 艺术家（可选）
- music_id: 音乐ID（可选，如果提供则直接绑定）
```

### 搜索歌词
```
GET /api/lyrics/search?keyword=<搜索关键词>
Headers: Authorization: Bearer <token>

返回：歌词列表
```

### 绑定歌词
```
POST /api/lyrics/bind
Headers: Authorization: Bearer <token>
Content-Type: application/json

Body:
{
  "music_id": 1,
  "lyrics_id": 2
}
```

### 获取歌词
```
GET /api/lyrics/get?music_id=<音乐ID>
Headers: Authorization: Bearer <token>

返回：歌词内容（LRC格式）
```

### 删除歌词
```
DELETE /api/lyrics/delete?id=<歌词ID>
Headers: Authorization: Bearer <token>
```

## 数据库结构

### lyrics 表
```sql
CREATE TABLE lyrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    music_id INTEGER,                    -- 绑定的音乐ID（可为空）
    user_id INTEGER NOT NULL,            -- 上传者ID
    title TEXT NOT NULL,                 -- 歌曲名称
    artist TEXT,                         -- 艺术家
    content TEXT NOT NULL,               -- 歌词内容（LRC格式）
    file_path TEXT NOT NULL,             -- 歌词文件路径
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (music_id) REFERENCES music(id) ON DELETE SET NULL
);
```

## 注意事项

1. 歌词文件必须是 UTF-8 编码
2. 支持 .lrc 和 .txt 格式（.txt会被转换为.lrc保存）
3. 一首歌曲只能绑定一个歌词文件
4. 如果需要更换歌词，先绑定新的歌词即可（会覆盖旧的绑定）
5. 删除歌曲时，绑定关系会自动清除（music_id设为NULL）

## 故障排除

### 歌词不显示
1. 检查歌曲是否已绑定歌词
2. 检查歌词文件格式是否正确
3. 检查时间标签是否符合 [mm:ss.xx] 格式

### 歌词不同步
1. 检查歌词文件的时间标签是否准确
2. 确保播放进度正常更新

### 上传失败
1. 检查文件格式（只支持.lrc和.txt）
2. 检查文件大小（限制10MB）
3. 检查网络连接和token是否有效

## 技术实现

### 后端（Go）
- `backend/models/lyrics.go` - 歌词数据模型
- `backend/database/lyrics_db.go` - 歌词数据库操作
- `backend/handlers/lyrics_handler.go` - 歌词API处理器

### 前端（Flutter）
- `lib/widgets/lyrics_widget.dart` - 歌词显示组件（支持滚动同步）
- `lib/widgets/lyrics_manage_dialog.dart` - 歌词管理对话框
- `lib/screens/music_player_screen.dart` - 集成歌词功能的音乐播放器

## 未来优化方向

- [ ] 支持在线搜索歌词（第三方API）
- [ ] 支持歌词编辑功能
- [ ] 支持双语歌词（中英文对照）
- [ ] 支持歌词翻译
- [ ] 支持卡拉OK模式（逐字高亮）
- [ ] 支持歌词分享到社交平台
