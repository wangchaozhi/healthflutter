package database

import (
	"log"
	"os"
	
	"backend/models"
)

// InitFileTransferTable 初始化文件传输表
func InitFileTransferTable() error {
	createTableSQL := `
	CREATE TABLE IF NOT EXISTS file_transfers (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL,
		file_name TEXT NOT NULL,
		file_path TEXT NOT NULL,
		file_size INTEGER NOT NULL,
		file_type TEXT NOT NULL,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (user_id) REFERENCES users(id)
	);`
	
	_, err := DB.Exec(createTableSQL)
	if err != nil {
		return err
	}
	
	log.Println("文件传输表初始化成功")
	return nil
}

// SaveFileTransfer 保存文件传输记录
func SaveFileTransfer(file *models.FileTransfer) error {
	_, err := DB.Exec(
		"INSERT INTO file_transfers (user_id, file_name, file_path, file_size, file_type) VALUES (?, ?, ?, ?, ?)",
		file.UserID, file.FileName, file.FilePath, file.FileSize, file.FileType,
	)
	return err
}

// GetUserFileTransfers 获取用户的文件列表（分页）
func GetUserFileTransfers(userID int, page, pageSize int) ([]models.FileTransfer, int, error) {
	// 获取总数
	var total int
	err := DB.QueryRow("SELECT COUNT(*) FROM file_transfers WHERE user_id = ?", userID).Scan(&total)
	if err != nil {
		return nil, 0, err
	}
	
	// 获取分页数据
	offset := (page - 1) * pageSize
	rows, err := DB.Query(
		"SELECT id, user_id, file_name, file_path, file_size, file_type, created_at FROM file_transfers WHERE user_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?",
		userID, pageSize, offset,
	)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	
	var files []models.FileTransfer
	for rows.Next() {
		var file models.FileTransfer
		err := rows.Scan(
			&file.ID,
			&file.UserID,
			&file.FileName,
			&file.FilePath,
			&file.FileSize,
			&file.FileType,
			&file.CreatedAt,
		)
		if err != nil {
			continue
		}
		// 格式化文件大小
		file.FileSizeStr = formatFileSizeInDB(file.FileSize)
		files = append(files, file)
	}
	
	return files, total, nil
}

// DeleteFileTransfer 删除文件传输记录
func DeleteFileTransfer(id, userID int) error {
	// 先获取文件路径
	var filePath string
	err := DB.QueryRow("SELECT file_path FROM file_transfers WHERE id = ? AND user_id = ?", id, userID).Scan(&filePath)
	if err != nil {
		return err
	}
	
	// 删除数据库记录
	_, err = DB.Exec("DELETE FROM file_transfers WHERE id = ? AND user_id = ?", id, userID)
	if err != nil {
		return err
	}
	
	// 删除物理文件
	if _, err := os.Stat(filePath); err == nil {
		os.Remove(filePath)
	}
	
	return nil
}

// GetFileTransferByID 根据ID获取文件信息
func GetFileTransferByID(id, userID int) (*models.FileTransfer, error) {
	var file models.FileTransfer
	err := DB.QueryRow(
		"SELECT id, user_id, file_name, file_path, file_size, file_type, created_at FROM file_transfers WHERE id = ? AND user_id = ?",
		id, userID,
	).Scan(
		&file.ID,
		&file.UserID,
		&file.FileName,
		&file.FilePath,
		&file.FileSize,
		&file.FileType,
		&file.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	file.FileSizeStr = formatFileSizeInDB(file.FileSize)
	return &file, nil
}

// 格式化文件大小（复用douyin_db.go中的函数）
// formatFileSizeInDB 已经在 douyin_db.go 中定义，这里直接使用

