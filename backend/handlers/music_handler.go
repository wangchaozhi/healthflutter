package handlers

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"backend/database"
	"backend/models"
	"backend/utils"
)

// MusicUploadHandler 音乐上传处理
func MusicUploadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := GetUserID(r)
	if userID == 0 {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 解析multipart form
	err := r.ParseMultipartForm(100 << 20) // 100 MB
	if err != nil {
		http.Error(w, "解析表单失败", http.StatusBadRequest)
		return
	}

	// 获取文件
	file, handler, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "获取文件失败", http.StatusBadRequest)
		return
	}
	defer file.Close()

	// 检查文件类型
	fileType := strings.ToLower(filepath.Ext(handler.Filename))
	allowedTypes := map[string]bool{
		".mp3":  true,
		".flac": true,
		".wav":  true,
		".m4a":  true,
		".aac":  true,
		".ogg":  true,
	}
	if !allowedTypes[fileType] {
		http.Error(w, "不支持的音乐文件格式", http.StatusBadRequest)
		return
	}

	// 创建上传目录
	uploadDir := "uploads/music"
	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		http.Error(w, "创建上传目录失败", http.StatusInternalServerError)
		return
	}

	// 生成唯一文件名
	timestamp := utils.NowTimestamp()
	filename := fmt.Sprintf("%d_%s_%s%s", userID, strings.TrimSuffix(handler.Filename, fileType), timestamp, fileType)
	filePath := filepath.Join(uploadDir, filename)

	// 保存文件
	dst, err := os.Create(filePath)
	if err != nil {
		http.Error(w, "创建文件失败", http.StatusInternalServerError)
		return
	}
	defer dst.Close()

	fileSize, err := io.Copy(dst, file)
	if err != nil {
		os.Remove(filePath)
		http.Error(w, "保存文件失败", http.StatusInternalServerError)
		return
	}

	// 获取音乐元数据（标题、艺术家等）
	title := strings.TrimSuffix(handler.Filename, fileType)
	artist := r.FormValue("artist")
	album := r.FormValue("album")

	// 保存到数据库
	music := &models.Music{
		UserID:   userID,
		Title:    title,
		Artist:   artist,
		Album:    album,
		FilePath: filePath,
		FileSize: fileSize,
		FileType: strings.TrimPrefix(fileType, "."),
	}

	if err := database.SaveMusic(music); err != nil {
		os.Remove(filePath)
		log.Printf("保存音乐记录失败: %v", err)
		http.Error(w, "保存失败", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(models.MusicUploadResponse{
		Success: true,
		Message: "上传成功",
		Music:   music,
	})
}

// MusicListHandler 获取音乐列表
func MusicListHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := GetUserID(r)
	if userID == 0 {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 获取分页参数
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page < 1 {
		page = 1
	}
	pageSize := 20 // 每页20首歌
	
	// 获取搜索关键词
	keyword := r.URL.Query().Get("keyword")

	// 获取音乐列表
	musicList, total, err := database.GetUserMusicList(userID, page, pageSize, keyword)
	if err != nil {
		http.Error(w, "获取列表失败", http.StatusInternalServerError)
		return
	}

	totalPages := (total + pageSize - 1) / pageSize

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(models.MusicListResponse{
		Success:     true,
		Message:     "获取成功",
		List:        musicList,
		CurrentPage: page,
		TotalPages:  totalPages,
		Total:       total,
	})
}

// MusicDeleteHandler 删除音乐
func MusicDeleteHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := GetUserID(r)
	if userID == 0 {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 获取音乐ID
	idStr := r.URL.Query().Get("id")
	if idStr == "" {
		http.Error(w, "缺少音乐ID参数", http.StatusBadRequest)
		return
	}

	musicID, err := strconv.Atoi(idStr)
	if err != nil {
		http.Error(w, "无效的音乐ID", http.StatusBadRequest)
		return
	}

	// 删除音乐
	if err := database.DeleteMusic(musicID, userID); err != nil {
		http.Error(w, "删除失败", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": "删除成功",
	})
}

// MusicStreamHandler 音乐流式传输
func MusicStreamHandler(w http.ResponseWriter, r *http.Request) {
	log.Printf("收到音乐流请求: %s", r.URL.String())
	
	if r.Method != http.MethodGet {
		log.Printf("方法不允许: %s", r.Method)
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	// 优先从URL参数获取token（用于音频播放器）
	tokenStr := r.URL.Query().Get("token")
	musicIDStr := r.URL.Query().Get("id")
	
	// 安全地打印 token（避免索引越界）
	tokenPreview := "无"
	if len(tokenStr) > 20 {
		tokenPreview = tokenStr[:20] + "..."
	} else if tokenStr != "" {
		tokenPreview = tokenStr
	}
	log.Printf("请求参数 - id: %s, token: %s", musicIDStr, tokenPreview)
	
	var userID int
	
	if tokenStr != "" {
		// 从token参数验证
		log.Printf("尝试从URL参数验证token")
		uid, err := ParseToken(tokenStr)
		if err != nil {
			log.Printf("❌ Token验证失败: %v", err)
			http.Error(w, fmt.Sprintf("无效的token: %v", err), http.StatusUnauthorized)
			return
		}
		log.Printf("✅ Token验证成功，用户ID: %d", uid)
		userID = uid
	} else {
		// 从Authorization头获取（正常API调用）
		log.Printf("尝试从Authorization头获取用户ID")
		userID = GetUserID(r)
		if userID == 0 {
			log.Printf("❌ 获取用户ID失败")
			http.Error(w, "未授权", http.StatusUnauthorized)
			return
		}
		log.Printf("✅ 从Authorization头获取用户ID成功: %d", userID)
	}

	// 获取音乐ID
	idStr := r.URL.Query().Get("id")
	if idStr == "" {
		log.Printf("❌ 缺少音乐ID参数")
		http.Error(w, "缺少音乐ID参数", http.StatusBadRequest)
		return
	}

	musicID, err := strconv.Atoi(idStr)
	if err != nil {
		log.Printf("❌ 无效的音乐ID: %s", idStr)
		http.Error(w, "无效的音乐ID", http.StatusBadRequest)
		return
	}

	log.Printf("查询音乐: ID=%d, UserID=%d", musicID, userID)
	// 获取音乐信息
	music, err := database.GetMusicByID(musicID, userID)
	if err != nil {
		log.Printf("❌ 音乐不存在: %v", err)
		http.Error(w, "音乐不存在", http.StatusNotFound)
		return
	}
	log.Printf("✅ 找到音乐: %s, 文件: %s", music.Title, music.FilePath)

	// 打开文件
	file, err := os.Open(music.FilePath)
	if err != nil {
		http.Error(w, "文件不存在", http.StatusNotFound)
		return
	}
	defer file.Close()

	// 获取文件信息
	fileInfo, err := file.Stat()
	if err != nil {
		http.Error(w, "获取文件信息失败", http.StatusInternalServerError)
		return
	}

	// 设置响应头
	w.Header().Set("Content-Type", "audio/"+music.FileType)
	w.Header().Set("Content-Length", strconv.FormatInt(fileInfo.Size(), 10))
	w.Header().Set("Accept-Ranges", "bytes")
	w.Header().Set("Cache-Control", "no-cache")
	
	log.Printf("音乐流式传输: id=%d, file=%s, size=%d", musicID, music.FilePath, fileInfo.Size())

	// 支持范围请求（用于进度条拖动）
	rangeHeader := r.Header.Get("Range")
	if rangeHeader != "" {
		// 解析 Range 头
		ranges := strings.Split(strings.TrimPrefix(rangeHeader, "bytes="), "-")
		if len(ranges) == 2 {
			start, _ := strconv.ParseInt(ranges[0], 10, 64)
			end := fileInfo.Size() - 1
			if ranges[1] != "" {
				end, _ = strconv.ParseInt(ranges[1], 10, 64)
			}

			// 设置206响应
			w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", start, end, fileInfo.Size()))
			w.Header().Set("Content-Length", strconv.FormatInt(end-start+1, 10))
			w.WriteHeader(http.StatusPartialContent)

			// 定位到起始位置
			file.Seek(start, 0)
			io.CopyN(w, file, end-start+1)
			return
		}
	}

	// 流式传输整个文件
	io.Copy(w, file)
}

