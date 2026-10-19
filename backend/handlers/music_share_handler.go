package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"

	"backend/database"
	"backend/models"
)

// CreateMusicShareHandler 创建音乐分享
func CreateMusicShareHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := GetUserID(r)
	if userID == 0 {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 获取音乐ID
	musicIDStr := r.URL.Query().Get("music_id")
	if musicIDStr == "" {
		http.Error(w, "缺少音乐ID", http.StatusBadRequest)
		return
	}

	musicID, err := strconv.Atoi(musicIDStr)
	if err != nil {
		http.Error(w, "无效的音乐ID", http.StatusBadRequest)
		return
	}

	// 验证音乐是否属于当前用户
	_, err = database.GetMusicByID(musicID, userID)
	if err != nil {
		http.Error(w, "音乐不存在或无权限", http.StatusNotFound)
		return
	}

	// 创建分享
	share, err := database.CreateMusicShare(userID, musicID)
	if err != nil {
		log.Printf("创建分享失败: %v", err)
		http.Error(w, "创建分享失败", http.StatusInternalServerError)
		return
	}

	// 构建完整的分享URL
	// 从请求中获取协议和主机名
	scheme := "http"
	if r.TLS != nil {
		scheme = "https"
	}
	host := r.Host
	shareURL := scheme + "://" + host + "/share/" + share.ShareToken

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(models.MusicShareResponse{
		Success:  true,
		Message:  "分享创建成功",
		Share:    share,
		ShareURL: shareURL,
	})

	log.Printf("创建音乐分享成功: user_id=%d, music_id=%d, token=%s", userID, musicID, share.ShareToken)
}

// GetUserSharesHandler 获取用户的所有分享
func GetUserSharesHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := GetUserID(r)
	if userID == 0 {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	shares, err := database.GetUserMusicShares(userID)
	if err != nil {
		log.Printf("获取分享列表失败: %v", err)
		http.Error(w, "获取分享列表失败", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(models.MusicShareListResponse{
		Success: true,
		Message: "获取成功",
		List:    shares,
	})
}

// DeleteMusicShareHandler 删除分享
func DeleteMusicShareHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := GetUserID(r)
	if userID == 0 {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 获取分享ID
	shareIDStr := r.URL.Query().Get("id")
	if shareIDStr == "" {
		http.Error(w, "缺少分享ID", http.StatusBadRequest)
		return
	}

	shareID, err := strconv.Atoi(shareIDStr)
	if err != nil {
		http.Error(w, "无效的分享ID", http.StatusBadRequest)
		return
	}

	// 删除分享
	err = database.DeleteMusicShare(shareID, userID)
	if err != nil {
		log.Printf("删除分享失败: %v", err)
		http.Error(w, "删除分享失败", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": "删除成功",
	})

	log.Printf("删除分享成功: share_id=%d, user_id=%d", shareID, userID)
}

// GetSharedMusicHandler 获取分享的音乐详情（公开访问，无需登录）
func GetSharedMusicHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	// 从URL参数获取分享token
	token := r.URL.Query().Get("token")
	if token == "" {
		http.Error(w, "缺少分享token", http.StatusBadRequest)
		return
	}

	// 获取分享信息
	share, err := database.GetMusicShareByToken(token)
	if err != nil || share == nil {
		log.Printf("分享不存在或已过期: token=%s, error=%v", token, err)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(models.MusicShareDetailResponse{
			Success: false,
			Message: "分享不存在或已失效",
		})
		return
	}

	// 增加访问次数
	database.IncrementShareViewCount(token)

	// 获取音乐详细信息
	music, err := database.GetMusicByID(share.MusicID, share.UserID)
	if err != nil {
		log.Printf("获取音乐信息失败: music_id=%d, error=%v", share.MusicID, err)
		http.Error(w, "音乐不存在", http.StatusNotFound)
		return
	}

	// 构建流媒体URL（公开访问，使用分享token）
	streamURL := "/api/music/share/stream?token=" + token

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(models.MusicShareDetailResponse{
		Success:   true,
		Message:   "获取成功",
		MusicID:   music.ID,
		Title:     music.Title,
		Artist:    music.Artist,
		Album:     music.Album,
		StreamURL: streamURL,
	})

	log.Printf("获取分享音乐成功: token=%s, music_id=%d", token, music.ID)
}

// StreamSharedMusicHandler 流式传输分享的音乐（公开访问，无需登录）
func StreamSharedMusicHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	// 从URL参数获取分享token
	token := r.URL.Query().Get("token")
	if token == "" {
		http.Error(w, "缺少分享token", http.StatusBadRequest)
		return
	}

	// 获取分享信息
	share, err := database.GetMusicShareByToken(token)
	if err != nil || share == nil {
		log.Printf("分享不存在或已过期: token=%s", token)
		http.Error(w, "分享不存在或已失效", http.StatusNotFound)
		return
	}

	// 获取音乐信息
	music, err := database.GetMusicByID(share.MusicID, share.UserID)
	if err != nil {
		log.Printf("音乐不存在: music_id=%d", share.MusicID)
		http.Error(w, "音乐不存在", http.StatusNotFound)
		return
	}

	// 使用 MusicStreamHandler 的逻辑来流式传输音乐文件
	// 直接读取文件并传输
	http.ServeFile(w, r, music.FilePath)

	log.Printf("流式传输分享音乐: token=%s, music_id=%d", token, music.ID)
}

// ShareWebPlayerHandler 分享音乐的Web播放页面（公开访问，无需登录）
func ShareWebPlayerHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	// 从URL路径获取分享token (例如: /share/abc123)
	token := r.URL.Path[len("/share/"):]
	if token == "" {
		http.Error(w, "缺少分享token", http.StatusBadRequest)
		return
	}

	// 获取分享信息
	share, err := database.GetMusicShareByToken(token)
	if err != nil || share == nil {
		log.Printf("分享不存在或已过期: token=%s", token)
		// 渲染错误页面
		w.WriteHeader(http.StatusNotFound)
		w.Write([]byte(`
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>分享不存在</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            padding: 40px;
            text-align: center;
            max-width: 500px;
        }
        .icon { font-size: 80px; margin-bottom: 20px; }
        .title { font-size: 24px; font-weight: bold; color: #333; margin-bottom: 10px; }
        .message { font-size: 16px; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">🎵</div>
        <div class="title">分享不存在或已失效</div>
        <div class="message">该音乐分享可能已被删除</div>
    </div>
</body>
</html>
		`))
		return
	}

	// 增加访问次数
	database.IncrementShareViewCount(token)

	// 获取音乐详细信息
	music, err := database.GetMusicByID(share.MusicID, share.UserID)
	if err != nil {
		log.Printf("获取音乐信息失败: music_id=%d, error=%v", share.MusicID, err)
		http.Error(w, "音乐不存在", http.StatusNotFound)
		return
	}

	// 准备模板数据
	data := struct {
		Title      string
		Artist     string
		Album      string
		StreamURL  string
		MusicID    int
		ShareToken string
	}{
		Title:      music.Title,
		Artist:     music.Artist,
		Album:      music.Album,
		StreamURL:  "/api/music/share/stream?token=" + token,
		MusicID:    music.ID,
		ShareToken: token,
	}

	// 解析并渲染模板（从嵌入的文件系统）
	tmpl, err := getTemplate("share_player.html")
	if err != nil {
		log.Printf("解析模板失败: %v", err)
		http.Error(w, "服务器错误", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := tmpl.Execute(w, data); err != nil {
		log.Printf("渲染模板失败: %v", err)
		http.Error(w, "服务器错误", http.StatusInternalServerError)
		return
	}

	log.Printf("渲染分享播放页面: token=%s, music_id=%d", token, music.ID)
}
