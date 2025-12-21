package handlers

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"backend/database"
	"backend/models"
)

// formatLyricsContent 格式化歌词内容
// 将所有内容挤在一行的LRC歌词格式化为标准的多行格式
func formatLyricsContent(content string) string {
	// 移除所有现有的换行符和回车符
	content = strings.ReplaceAll(content, "\r\n", "")
	content = strings.ReplaceAll(content, "\n", "")
	content = strings.ReplaceAll(content, "\r", "")
	
	// LRC时间标签的正则表达式: [mm:ss.xx] 或 [mm:ss.xxx]
	timeRegex := regexp.MustCompile(`\[(\d{2}):(\d{2})\.(\d{2,3})\]`)
	
	// 在每个时间标签前添加换行符（第一个除外）
	formatted := timeRegex.ReplaceAllStringFunc(content, func(match string) string {
		// 如果这是内容的开头，不添加换行
		if strings.Index(content, match) == 0 {
			return match
		}
		return "\n" + match
	})
	
	// 确保以换行符结尾
	if !strings.HasSuffix(formatted, "\n") {
		formatted += "\n"
	}
	
	return formatted
}

// LyricsUploadHandler 歌词上传处理
func LyricsUploadHandler(w http.ResponseWriter, r *http.Request) {
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
	err := r.ParseMultipartForm(10 << 20) // 10 MB
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
	if fileType != ".lrc" && fileType != ".txt" {
		http.Error(w, "只支持 .lrc 或 .txt 歌词文件", http.StatusBadRequest)
		return
	}

	// 读取歌词内容
	content, err := io.ReadAll(file)
	if err != nil {
		http.Error(w, "读取文件失败", http.StatusInternalServerError)
		return
	}

	// 格式化歌词内容（自动处理挤在一行的情况）
	formattedContent := formatLyricsContent(string(content))
	log.Printf("歌词格式化：原始长度=%d，格式化后长度=%d", len(content), len(formattedContent))

	// 创建上传目录
	uploadDir := "uploads/lyrics"
	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		http.Error(w, "创建上传目录失败", http.StatusInternalServerError)
		return
	}

	// 生成唯一文件名
	timestamp := time.Now().Format("20060102150405")
	filename := fmt.Sprintf("%d_%s_%s.lrc", userID, strings.TrimSuffix(handler.Filename, fileType), timestamp)
	filePath := filepath.Join(uploadDir, filename)

	// 保存格式化后的文件
	err = os.WriteFile(filePath, []byte(formattedContent), 0644)
	if err != nil {
		http.Error(w, "保存文件失败", http.StatusInternalServerError)
		return
	}

	log.Printf("歌词文件已保存并格式化: %s", filePath)

	// 获取歌词元数据（标题、艺术家等）
	title := r.FormValue("title")
	if title == "" {
		title = strings.TrimSuffix(handler.Filename, fileType)
	}
	artist := r.FormValue("artist")
	musicIDStr := r.FormValue("music_id")

	var musicID int
	if musicIDStr != "" {
		musicID, _ = strconv.Atoi(musicIDStr)
	}

	// 保存到数据库
	lyrics := &models.Lyrics{
		MusicID:  musicID,
		UserID:   userID,
		Title:    title,
		Artist:   artist,
		Content:  formattedContent, // 使用格式化后的内容
		FilePath: filePath,
	}

	if err := database.SaveLyrics(lyrics); err != nil {
		os.Remove(filePath)
		log.Printf("保存歌词记录失败: %v", err)
		http.Error(w, "保存失败", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(models.LyricsUploadResponse{
		Success: true,
		Message: "上传成功",
		Lyrics:  lyrics,
	})
}

// LyricsSearchHandler 歌词搜索处理
func LyricsSearchHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := GetUserID(r)
	if userID == 0 {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 获取搜索关键词
	keyword := r.URL.Query().Get("keyword")
	if keyword == "" {
		// 如果没有关键词，返回用户所有歌词
		lyricsList, err := database.GetUserLyrics(userID)
		if err != nil {
			http.Error(w, "查询失败", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(models.LyricsListResponse{
			Success: true,
			Message: "获取成功",
			List:    lyricsList,
			Total:   len(lyricsList),
		})
		return
	}

	// 搜索歌词
	lyricsList, err := database.SearchLyrics(userID, keyword)
	if err != nil {
		http.Error(w, "搜索失败", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(models.LyricsListResponse{
		Success: true,
		Message: "搜索成功",
		List:    lyricsList,
		Total:   len(lyricsList),
	})
}

// LyricsBindHandler 歌词绑定处理
func LyricsBindHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := GetUserID(r)
	if userID == 0 {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	var req models.LyricsBindRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "无效的请求数据", http.StatusBadRequest)
		return
	}

	// 验证输入
	if req.MusicID == 0 || req.LyricsID == 0 {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(models.LyricsBindResponse{
			Success: false,
			Message: "音乐ID和歌词ID不能为空",
		})
		return
	}

	// 绑定歌词到音乐
	if err := database.BindLyricsToMusic(req.LyricsID, req.MusicID, userID); err != nil {
		log.Printf("绑定歌词失败: %v", err)
		http.Error(w, "绑定失败", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(models.LyricsBindResponse{
		Success: true,
		Message: "绑定成功",
	})
}

// LyricsGetByMusicIDHandler 根据音乐ID获取歌词（公开访问，不需要登录）
func LyricsGetByMusicIDHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	// 获取音乐ID
	musicIDStr := r.URL.Query().Get("music_id")
	if musicIDStr == "" {
		http.Error(w, "缺少音乐ID参数", http.StatusBadRequest)
		return
	}

	musicID, err := strconv.Atoi(musicIDStr)
	if err != nil {
		http.Error(w, "无效的音乐ID", http.StatusBadRequest)
		return
	}

	// 获取歌词
	lyrics, err := database.GetLyricsByMusicID(musicID)
	if err != nil {
		// 没有找到歌词，返回空结果
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(models.LyricsUploadResponse{
			Success: true,
			Message: "未找到歌词",
			Lyrics:  nil,
		})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(models.LyricsUploadResponse{
		Success: true,
		Message: "获取成功",
		Lyrics:  lyrics,
	})
}

// LyricsDeleteHandler 删除歌词
func LyricsDeleteHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := GetUserID(r)
	if userID == 0 {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 获取歌词ID
	idStr := r.URL.Query().Get("id")
	if idStr == "" {
		http.Error(w, "缺少歌词ID参数", http.StatusBadRequest)
		return
	}

	lyricsID, err := strconv.Atoi(idStr)
	if err != nil {
		http.Error(w, "无效的歌词ID", http.StatusBadRequest)
		return
	}

	// 删除歌词
	if err := database.DeleteLyrics(lyricsID, userID); err != nil {
		http.Error(w, "删除失败", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": "删除成功",
	})
}

// LyricsUnbindHandler 解除歌词绑定
func LyricsUnbindHandler(w http.ResponseWriter, r *http.Request) {
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
		http.Error(w, "缺少音乐ID参数", http.StatusBadRequest)
		return
	}

	musicID, err := strconv.Atoi(musicIDStr)
	if err != nil {
		http.Error(w, "无效的音乐ID", http.StatusBadRequest)
		return
	}

	// 解除绑定
	if err := database.UnbindLyricsFromMusic(musicID); err != nil {
		log.Printf("解除歌词绑定失败: music_id=%d, error=%v", musicID, err)
		http.Error(w, "解除绑定失败", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": "解除绑定成功",
	})
}
