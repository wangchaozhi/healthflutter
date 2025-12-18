package handlers

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"

	"backend/database"
	"backend/models"
	"backend/services"
)

// 抖音解析处理器
func DouyinParsingHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := GetUserID(r)
	if userID == 0 {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	var req models.DouyinParsingRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "无效的请求数据", http.StatusBadRequest)
		return
	}

	// 提取URL
	url, err := services.ExtractURL(req.Text)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(models.DouyinParsingResponse{
			Success: false,
			Message: err.Error(),
		})
		return
	}

	// 先检查该用户是否已解析过此URL且文件存在
	urlExists, err := database.URLExists(userID, url)
	if err != nil {
		log.Printf("检查URL是否存在失败: %v", err)
	} else if urlExists {
		// 该用户已解析过，检查文件是否存在
		filesExist, err := database.CheckURLFilesExist(userID, url)
		if err != nil {
			log.Printf("检查文件是否存在失败: %v", err)
		} else if filesExist {
			// 该用户已解析且文件存在，直接返回成功
			log.Printf("用户已解析过此URL且文件存在，直接返回成功: %s, 用户ID: %d", url, userID)
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(models.DouyinParsingResponse{
				Success: true,
				Message: "解析成功（文件已存在）",
				Data:    url,
			})
			return
		}
	}

	// 检查URL是否已被任何用户解析过且文件存在
	parsedAndExists, paths, err := database.CheckURLParsedAndFileExists(url)
	if err != nil {
		log.Printf("检查URL是否已解析失败: %v", err)
	} else if parsedAndExists {
		// URL已被解析过且文件存在，直接返回成功，并为当前用户创建记录
		log.Printf("URL已被其他用户解析过且文件存在，直接返回成功: %s, 用户ID: %d", url, userID)
		
		// 保存URL到数据库（为该用户创建URL记录，保证唯一性）
		// SaveDouyinURL 使用 INSERT OR IGNORE，已存在的记录会被忽略
		if err := database.SaveDouyinURL(userID, url); err != nil {
			log.Printf("保存URL失败: %v", err)
		}

		// 为该用户创建文件记录（如果还没有，保证唯一性）
		// CreateFileRecordForUser 内部会检查并创建，SaveDouyinFile 使用 INSERT OR IGNORE 保证唯一性
		if err := database.CreateFileRecordForUser(userID, url, paths); err != nil {
			log.Printf("为用户创建文件记录失败: %v", err)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(models.DouyinParsingResponse{
			Success: true,
			Message: "解析成功（使用已有文件）",
			Data:    url,
		})
		return
	}

	// URL未被解析过或文件不存在，执行解析命令
	result, err := services.ParseDouyinURL(req.Text)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(models.DouyinParsingResponse{
			Success: false,
			Message: err.Error(),
		})
		return
	}

	log.Printf("解析抖音链接成功: %s, 用户ID: %d", result.Data, userID)

	// 如果解析成功，保存URL并扫描文件
	if result.Success {
		// 保存URL到数据库
		if err := database.SaveDouyinURL(userID, url); err != nil {
			log.Printf("保存URL失败: %v", err)
		}

		// 扫描并保存文件
		go func() {
			if err := services.ScanAndSaveFiles(userID, url); err != nil {
				log.Printf("扫描文件失败: %v", err)
			}
		}()
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

// 获取抖音文件列表处理器
func DouyinFileListHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := GetUserID(r)
	if userID == 0 {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	files, err := database.GetUserDouyinFiles(userID)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(models.DouyinFileListResponse{
			Success: false,
			Message: "获取文件列表失败",
		})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(models.DouyinFileListResponse{
		Success: true,
		Message: "获取成功",
		List:    files,
	})
}

// 下载抖音文件处理器
func DouyinDownloadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := GetUserID(r)
	if userID == 0 {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 从URL参数获取文件ID
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

	// 验证文件是否属于当前用户
	file, err := database.GetDouyinFileByID(fileID, userID)
	if err != nil {
		http.Error(w, "文件不存在或无权限", http.StatusNotFound)
		return
	}

	// 检查文件是否存在
	if _, err := os.Stat(file.Path); os.IsNotExist(err) {
		http.Error(w, "文件不存在", http.StatusNotFound)
		return
	}

	// 设置响应头，支持文件下载
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", file.FileName))
	w.Header().Set("Content-Length", strconv.FormatInt(file.FileSize, 10))

	// 读取并发送文件
	http.ServeFile(w, r, file.Path)
}

// 从请求头获取用户ID（辅助函数）
// getUserID 函数已移至 auth.go
