package database

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"
	"backend/models"
)

var DB *sql.DB

// 初始化抖音文件表
func InitDouyinTable() error {
	// 创建抖音URL表（存储解析的URL）
	createUrlTableSQL := `
	CREATE TABLE IF NOT EXISTS douyin_urls (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL,
		url TEXT NOT NULL,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (user_id) REFERENCES users(id),
		UNIQUE(user_id, url)
	);`
	_, err := DB.Exec(createUrlTableSQL)
	if err != nil {
		return err
	}

	// 创建抖音文件表
	createTableSQL := `
	CREATE TABLE IF NOT EXISTS douyin_files (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL,
		url TEXT,
		file_name TEXT NOT NULL,
		file_size INTEGER NOT NULL,
		file_size_str TEXT NOT NULL,
		modified_time TEXT NOT NULL,
		path TEXT NOT NULL,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (user_id) REFERENCES users(id),
		UNIQUE(user_id, path)
	);`

	_, err = DB.Exec(createTableSQL)
	if err != nil {
		return err
	}

	// 如果url字段不存在，添加url字段（用于迁移旧数据）
	_, _ = DB.Exec("ALTER TABLE douyin_files ADD COLUMN url TEXT")
	
	// 尝试移除旧的path UNIQUE约束（如果存在）
	// SQLite不支持直接删除UNIQUE约束，需要重建表，这里先忽略错误
	_, _ = DB.Exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_user_path ON douyin_files(user_id, path)")

	return nil
}

// 检查文件是否已存在（检查特定用户的文件）
func FileExists(userID int, path string) (bool, error) {
	var count int
	err := DB.QueryRow("SELECT COUNT(*) FROM douyin_files WHERE user_id = ? AND path = ?", userID, path).Scan(&count)
	if err != nil {
		return false, err
	}
	return count > 0, nil
}

// 检查文件是否已存在（检查特定用户的文件和URL）
func FileExistsWithURL(userID int, path string, url string) (bool, error) {
	var count int
	err := DB.QueryRow("SELECT COUNT(*) FROM douyin_files WHERE user_id = ? AND path = ? AND url = ?", userID, path, url).Scan(&count)
	if err != nil {
		return false, err
	}
	return count > 0, nil
}

// 保存抖音文件信息（如果已存在则忽略，保证唯一性）
func SaveDouyinFile(file *models.DouyinFile) error {
	_, err := DB.Exec(
		"INSERT OR IGNORE INTO douyin_files (user_id, url, file_name, file_size, file_size_str, modified_time, path) VALUES (?, ?, ?, ?, ?, ?, ?)",
		file.UserID, file.URL, file.FileName, file.FileSize, file.FileSizeStr, file.ModifiedTime, file.Path,
	)
	return err
}

// 检查URL是否已解析（检查douyin_urls表）
func URLExists(userID int, url string) (bool, error) {
	var count int
	err := DB.QueryRow("SELECT COUNT(*) FROM douyin_urls WHERE user_id = ? AND url = ?", userID, url).Scan(&count)
	if err != nil {
		return false, err
	}
	return count > 0, nil
}

// 保存解析的URL
func SaveDouyinURL(userID int, url string) error {
	_, err := DB.Exec(
		"INSERT OR IGNORE INTO douyin_urls (user_id, url) VALUES (?, ?)",
		userID, url,
	)
	return err
}

// 检查URL对应的文件是否存在（检查特定用户）
func CheckURLFilesExist(userID int, url string) (bool, error) {
	rows, err := DB.Query(
		"SELECT path FROM douyin_files WHERE user_id = ? AND url = ?",
		userID, url,
	)
	if err != nil {
		return false, err
	}
	defer rows.Close()

	hasFiles := false
	for rows.Next() {
		var path string
		if err := rows.Scan(&path); err != nil {
			continue
		}
		// 检查文件是否存在
		if _, err := os.Stat(path); err == nil {
			hasFiles = true
			break
		}
	}

	return hasFiles, nil
}

// 检查URL是否已被任何用户解析过且文件存在
func CheckURLParsedAndFileExists(url string) (bool, []string, error) {
	rows, err := DB.Query(
		"SELECT DISTINCT path FROM douyin_files WHERE url = ?",
		url,
	)
	if err != nil {
		return false, nil, err
	}
	defer rows.Close()

	var paths []string
	hasValidFile := false
	for rows.Next() {
		var path string
		if err := rows.Scan(&path); err != nil {
			continue
		}
		paths = append(paths, path)
		// 检查文件是否存在
		if _, err := os.Stat(path); err == nil {
			hasValidFile = true
		}
	}

	return hasValidFile, paths, nil
}

// 为用户创建文件记录（如果不存在）
func CreateFileRecordForUser(userID int, url string, paths []string) error {
	for _, path := range paths {
		// 检查文件是否存在
		fileInfo, err := os.Stat(path)
		if err != nil {
			continue // 文件不存在，跳过
		}

		// 检查该用户是否已有此文件记录
		exists, err := FileExistsWithURL(userID, path, url)
		if err != nil {
			continue
		}
		if exists {
			continue // 已存在，跳过
		}

		// 获取文件扩展名判断是否为视频文件
		ext := strings.ToLower(filepath.Ext(path))
		videoExts := []string{".mp4", ".avi", ".mov", ".mkv", ".flv", ".wmv", ".webm"}
		isVideo := false
		for _, v := range videoExts {
			if ext == v {
				isVideo = true
				break
			}
		}
		if !isVideo {
			continue // 不是视频文件，跳过
		}

		// 格式化文件大小
		fileSize := fileInfo.Size()
		fileSizeStr := formatFileSizeInDB(fileSize)

		// 保存文件信息
		file := models.DouyinFile{
			UserID:       userID,
			URL:          url,
			FileName:     filepath.Base(path),
			FileSize:     fileSize,
			FileSizeStr:  fileSizeStr,
			ModifiedTime: fileInfo.ModTime().Format("2006-01-02 15:04:05"),
			Path:         path,
			CreatedAt:    time.Now().Format("2006-01-02 15:04:05"),
		}

		if err := SaveDouyinFile(&file); err != nil {
			log.Printf("为用户创建文件记录失败: %v", err)
		}
	}

	return nil
}

// 格式化文件大小（database包内部使用）
func formatFileSizeInDB(size int64) string {
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

// 获取用户的文件列表
func GetUserDouyinFiles(userID int) ([]models.DouyinFile, error) {
	rows, err := DB.Query(
		"SELECT id, user_id, url, file_name, file_size, file_size_str, modified_time, path, created_at FROM douyin_files WHERE user_id = ? ORDER BY created_at DESC",
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var files []models.DouyinFile
	for rows.Next() {
		var file models.DouyinFile
		err := rows.Scan(
			&file.ID,
			&file.UserID,
			&file.URL,
			&file.FileName,
			&file.FileSize,
			&file.FileSizeStr,
			&file.ModifiedTime,
			&file.Path,
			&file.CreatedAt,
		)
		if err != nil {
			continue
		}
		files = append(files, file)
	}

	return files, nil
}

// 根据ID获取文件信息
func GetDouyinFileByID(id, userID int) (*models.DouyinFile, error) {
	var file models.DouyinFile
	err := DB.QueryRow(
		"SELECT id, user_id, url, file_name, file_size, file_size_str, modified_time, path, created_at FROM douyin_files WHERE id = ? AND user_id = ?",
		id, userID,
	).Scan(
		&file.ID,
		&file.UserID,
		&file.URL,
		&file.FileName,
		&file.FileSize,
		&file.FileSizeStr,
		&file.ModifiedTime,
		&file.Path,
		&file.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &file, nil
}

