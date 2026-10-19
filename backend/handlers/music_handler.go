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

const maxMusicUploadBytes = 100 << 20

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

	// MaxBytesReader 才会限制整个请求体，ParseMultipartForm 的参数仅控制内存用量。
	r.Body = http.MaxBytesReader(w, r.Body, maxMusicUploadBytes+(1<<20))
	err := r.ParseMultipartForm(8 << 20)
	if err != nil {
		if _, ok := err.(*http.MaxBytesError); ok {
			http.Error(w, "文件不能超过100MB", http.StatusRequestEntityTooLarge)
			return
		}
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
	originalName := filepath.Base(handler.Filename)
	fileType := strings.ToLower(filepath.Ext(originalName))
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
	baseName := strings.TrimSuffix(originalName, fileType)
	baseName = strings.Map(func(r rune) rune {
		if r == '/' || r == '\\' || r == 0 {
			return '_'
		}
		return r
	}, baseName)
	filename := fmt.Sprintf("%d_%s_%s%s", userID, baseName, timestamp, fileType)
	filePath := filepath.Join(uploadDir, filename)

	// 保存文件
	dst, err := os.Create(filePath)
	if err != nil {
		http.Error(w, "创建文件失败", http.StatusInternalServerError)
		return
	}

	fileSize, err := io.Copy(dst, io.LimitReader(file, maxMusicUploadBytes+1))
	if err != nil {
		_ = dst.Close()
		os.Remove(filePath)
		http.Error(w, "保存文件失败", http.StatusInternalServerError)
		return
	}
	if fileSize > maxMusicUploadBytes {
		_ = dst.Close()
		os.Remove(filePath)
		http.Error(w, "文件不能超过100MB", http.StatusRequestEntityTooLarge)
		return
	}
	if err := dst.Close(); err != nil {
		os.Remove(filePath)
		http.Error(w, "保存文件失败", http.StatusInternalServerError)
		return
	}

	// 获取音乐元数据（标题、艺术家等）
	title := strings.TrimSuffix(originalName, fileType)
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

// MusicStreamTicketHandler 为已认证用户签发绑定到指定音乐的短期播放凭证。
func MusicStreamTicketHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}
	userID := GetUserID(r)
	musicID, err := strconv.Atoi(r.URL.Query().Get("id"))
	if userID <= 0 || err != nil || musicID <= 0 {
		http.Error(w, "无效的音乐ID", http.StatusBadRequest)
		return
	}
	if _, err := database.GetMusicByID(musicID, userID); err != nil {
		http.Error(w, "音乐不存在", http.StatusNotFound)
		return
	}
	ticket, err := GenerateMusicStreamTicket(userID, musicID)
	if err != nil {
		log.Printf("生成播放凭证失败: %v", err)
		http.Error(w, "生成播放凭证失败", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{"success": true, "ticket": ticket})
}

// MusicStreamHandler 使用短期播放凭证传输音乐。
func MusicStreamHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	musicID, err := strconv.Atoi(r.URL.Query().Get("id"))
	if err != nil || musicID <= 0 {
		http.Error(w, "无效的音乐ID", http.StatusBadRequest)
		return
	}
	claims, err := VerifyMusicStreamTicket(r.URL.Query().Get("ticket"))
	if err != nil || claims.MusicID != musicID {
		http.Error(w, "无效或已过期的播放凭证", http.StatusUnauthorized)
		return
	}
	music, err := database.GetMusicByID(musicID, claims.UserID)
	if err != nil {
		http.Error(w, "音乐不存在", http.StatusNotFound)
		return
	}
	file, err := os.Open(music.FilePath)
	if err != nil {
		http.Error(w, "文件不存在", http.StatusNotFound)
		return
	}
	defer file.Close()
	fileInfo, err := file.Stat()
	if err != nil {
		http.Error(w, "获取文件信息失败", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "audio/"+music.FileType)
	w.Header().Set("Cache-Control", "private, no-store")
	// ServeContent 对 Range 做完整边界校验，无效范围返回 416。
	http.ServeContent(w, r, filepath.Base(music.FilePath), fileInfo.ModTime(), file)
}
