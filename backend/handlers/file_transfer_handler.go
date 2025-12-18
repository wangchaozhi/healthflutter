package handlers

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
	
	"backend/database"
	"backend/models"
)

// 格式化文件大小
func formatFileSize(size int64) string {
	const unit = 1024
	if size < unit {
		return fmt.Sprintf("%d B", size)
	}
	div, exp := int64(unit), 0
	for n := size / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(size)/float64(div), "KMGTPE"[exp])
}

// 文件上传目录
const uploadDir = "uploads"

// FileUploadHandler 处理文件上传
func FileUploadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := getUserID(r)
	if userID == 0 {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 解析multipart form
	err := r.ParseMultipartForm(10 << 20) // 10MB
	if err != nil {
		http.Error(w, "解析表单失败", http.StatusBadRequest)
		return
	}

	file, handler, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "获取文件失败", http.StatusBadRequest)
		return
	}
	defer file.Close()

	// 创建上传目录
	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		http.Error(w, "创建目录失败", http.StatusInternalServerError)
		return
	}

	// 生成唯一文件名
	timestamp := time.Now().Format("20060102150405")
	ext := filepath.Ext(handler.Filename)
	fileName := fmt.Sprintf("%s_%s%s", strings.TrimSuffix(handler.Filename, ext), timestamp, ext)
	filePath := filepath.Join(uploadDir, fmt.Sprintf("%d_%s", userID, fileName))

	// 创建目标文件
	dst, err := os.Create(filePath)
	if err != nil {
		http.Error(w, "创建文件失败", http.StatusInternalServerError)
		return
	}
	defer dst.Close()

	// 复制文件内容
	fileSize, err := io.Copy(dst, file)
	if err != nil {
		os.Remove(filePath)
		http.Error(w, "保存文件失败", http.StatusInternalServerError)
		return
	}

	// 获取文件类型
	fileType := strings.ToLower(ext)
	if fileType == "" {
		fileType = "unknown"
	} else {
		fileType = fileType[1:] // 移除点号
	}

	// 保存到数据库
	fileTransfer := &models.FileTransfer{
		UserID:   userID,
		FileName: handler.Filename,
		FilePath: filePath,
		FileSize: fileSize,
		FileType: fileType,
		CreatedAt: time.Now().Format("2006-01-02 15:04:05"),
	}

	if err := database.SaveFileTransfer(fileTransfer); err != nil {
		os.Remove(filePath)
		http.Error(w, "保存记录失败", http.StatusInternalServerError)
		return
	}

	fileTransfer.FileSizeStr = formatFileSize(fileSize)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(models.FileUploadResponse{
		Success: true,
		Message: "上传成功",
		Data:    *fileTransfer,
	})
}

// FileListHandler 获取文件列表（分页）
func FileListHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := getUserID(r)
	if userID == 0 {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 获取分页参数
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page < 1 {
		page = 1
	}
	pageSize, _ := strconv.Atoi(r.URL.Query().Get("page_size"))
	if pageSize < 1 {
		pageSize = 10
	}
	if pageSize > 100 {
		pageSize = 100
	}

	// 获取文件列表
	files, total, err := database.GetUserFileTransfers(userID, page, pageSize)
	if err != nil {
		http.Error(w, "获取文件列表失败", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(models.FileTransferListResponse{
		Success: true,
		Message: "获取成功",
		Data: models.FileListData{
			List:     files,
			Total:    total,
			Page:     page,
			PageSize: pageSize,
		},
	})
}

// FileDeleteHandler 删除文件
func FileDeleteHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := getUserID(r)
	if userID == 0 {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 获取文件ID
	idStr := r.URL.Query().Get("id")
	if idStr == "" {
		http.Error(w, "缺少文件ID参数", http.StatusBadRequest)
		return
	}

	fileID, err := strconv.Atoi(idStr)
	if err != nil {
		http.Error(w, "无效的文件ID", http.StatusBadRequest)
		return
	}

	// 删除文件
	if err := database.DeleteFileTransfer(fileID, userID); err != nil {
		http.Error(w, "删除失败", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": "删除成功",
	})
}

// FileDownloadHandler 下载文件
func FileDownloadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := getUserID(r)
	if userID == 0 {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 获取文件ID
	idStr := r.URL.Query().Get("id")
	if idStr == "" {
		http.Error(w, "缺少文件ID参数", http.StatusBadRequest)
		return
	}

	fileID, err := strconv.Atoi(idStr)
	if err != nil {
		http.Error(w, "无效的文件ID", http.StatusBadRequest)
		return
	}

	// 获取文件信息
	file, err := database.GetFileTransferByID(fileID, userID)
	if err != nil {
		http.Error(w, "文件不存在或无权限", http.StatusNotFound)
		return
	}

	// 检查文件是否存在
	if _, err := os.Stat(file.FilePath); os.IsNotExist(err) {
		http.Error(w, "文件不存在", http.StatusNotFound)
		return
	}

	// 设置响应头
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", file.FileName))
	w.Header().Set("Content-Length", strconv.FormatInt(file.FileSize, 10))

	// 读取并发送文件
	http.ServeFile(w, r, file.FilePath)
}

// SaveClipboardHandler 保存粘贴板内容为txt文件
func SaveClipboardHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := getUserID(r)
	if userID == 0 {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	var req struct {
		Content string `json:"content"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "无效的请求数据", http.StatusBadRequest)
		return
	}

	if req.Content == "" {
		http.Error(w, "内容不能为空", http.StatusBadRequest)
		return
	}

	// 创建上传目录
	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		http.Error(w, "创建目录失败", http.StatusInternalServerError)
		return
	}

	// 生成文件名（日期时间格式）
	timestamp := time.Now().Format("2006-01-02_15-04-05")
	fileName := fmt.Sprintf("clipboard_%s.txt", timestamp)
	filePath := filepath.Join(uploadDir, fmt.Sprintf("%d_%s", userID, fileName))

	// 保存文件
	if err := os.WriteFile(filePath, []byte(req.Content), 0644); err != nil {
		http.Error(w, "保存文件失败", http.StatusInternalServerError)
		return
	}

	// 获取文件大小
	fileInfo, err := os.Stat(filePath)
	if err != nil {
		os.Remove(filePath)
		http.Error(w, "获取文件信息失败", http.StatusInternalServerError)
		return
	}

	// 保存到数据库
	fileTransfer := &models.FileTransfer{
		UserID:   userID,
		FileName: fileName,
		FilePath: filePath,
		FileSize: fileInfo.Size(),
		FileType: "txt",
		CreatedAt: time.Now().Format("2006-01-02 15:04:05"),
	}

	if err := database.SaveFileTransfer(fileTransfer); err != nil {
		os.Remove(filePath)
		http.Error(w, "保存记录失败", http.StatusInternalServerError)
		return
	}

	// 格式化文件大小
	fileTransfer.FileSizeStr = formatFileSize(fileInfo.Size())

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(models.FileUploadResponse{
		Success: true,
		Message: "保存成功",
		Data:    *fileTransfer,
	})
}

