package database

import (
	"log"
	"os"
	"time"
	
	"backend/models"
)

// InitMusicTable 初始化音乐表
func InitMusicTable() error {
	createTableSQL := `
	CREATE TABLE IF NOT EXISTS music (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL,
		title TEXT NOT NULL,
		artist TEXT,
		album TEXT,
		file_path TEXT NOT NULL,
		file_size INTEGER NOT NULL,
		duration INTEGER DEFAULT 0,
		file_type TEXT NOT NULL,
		cover_path TEXT,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (user_id) REFERENCES users(id),
		UNIQUE(user_id, file_path)
	);`
	
	_, err := DB.Exec(createTableSQL)
	if err != nil {
		return err
	}
	
	log.Println("音乐表初始化成功")
	return nil
}

// SaveMusic 保存音乐记录
func SaveMusic(music *models.Music) error {
	result, err := DB.Exec(
		`INSERT INTO music (user_id, title, artist, album, file_path, file_size, duration, file_type, cover_path) 
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		music.UserID, music.Title, music.Artist, music.Album, music.FilePath, 
		music.FileSize, music.Duration, music.FileType, music.CoverPath,
	)
	if err != nil {
		return err
	}
	
	id, err := result.LastInsertId()
	if err != nil {
		return err
	}
	music.ID = int(id)
	
	return nil
}

// GetUserMusicList 获取用户的音乐列表（分页，支持搜索）
func GetUserMusicList(userID int, page, pageSize int, keyword string) ([]models.Music, int, error) {
	// 构建 WHERE 条件
	whereClause := "user_id = ?"
	args := []interface{}{userID}
	
	if keyword != "" {
		whereClause += " AND (title LIKE ? OR artist LIKE ? OR album LIKE ?)"
		searchPattern := "%" + keyword + "%"
		args = append(args, searchPattern, searchPattern, searchPattern)
	}
	
	// 获取总数
	var total int
	countQuery := "SELECT COUNT(*) FROM music WHERE " + whereClause
	err := DB.QueryRow(countQuery, args...).Scan(&total)
	if err != nil {
		return nil, 0, err
	}
	
	// 获取分页数据 - 重新构建参数列表（因为 args 已被 countQuery 使用）
	offset := (page - 1) * pageSize
	listQuery := `SELECT id, user_id, title, artist, album, file_path, file_size, duration, file_type, cover_path, created_at 
		FROM music WHERE ` + whereClause + ` ORDER BY created_at DESC LIMIT ? OFFSET ?`
	
	// 重新构建参数切片
	listArgs := []interface{}{userID}
	if keyword != "" {
		searchPattern := "%" + keyword + "%"
		listArgs = append(listArgs, searchPattern, searchPattern, searchPattern)
	}
	listArgs = append(listArgs, pageSize, offset)
	
	rows, err := DB.Query(listQuery, listArgs...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	
	var musicList []models.Music
	for rows.Next() {
		var music models.Music
		var createdAt string
		err := rows.Scan(
			&music.ID,
			&music.UserID,
			&music.Title,
			&music.Artist,
			&music.Album,
			&music.FilePath,
			&music.FileSize,
			&music.Duration,
			&music.FileType,
			&music.CoverPath,
			&createdAt,
		)
		if err != nil {
			continue
		}
		
		// 格式化文件大小
		music.FileSizeStr = formatFileSizeInDB(music.FileSize)
		
		// 格式化日期时间
		if t, err := time.Parse(time.RFC3339, createdAt); err == nil {
			music.CreatedAt = t.Format("2006-01-02 15:04:05")
		} else {
			music.CreatedAt = createdAt
		}
		
		musicList = append(musicList, music)
	}
	
	return musicList, total, nil
}

// GetMusicByID 根据ID获取音乐信息
func GetMusicByID(id, userID int) (*models.Music, error) {
	var music models.Music
	var createdAt string
	err := DB.QueryRow(
		`SELECT id, user_id, title, artist, album, file_path, file_size, duration, file_type, cover_path, created_at 
		FROM music WHERE id = ? AND user_id = ?`,
		id, userID,
	).Scan(
		&music.ID,
		&music.UserID,
		&music.Title,
		&music.Artist,
		&music.Album,
		&music.FilePath,
		&music.FileSize,
		&music.Duration,
		&music.FileType,
		&music.CoverPath,
		&createdAt,
	)
	if err != nil {
		return nil, err
	}
	
	music.FileSizeStr = formatFileSizeInDB(music.FileSize)
	
	// 格式化日期时间
	if t, err := time.Parse(time.RFC3339, createdAt); err == nil {
		music.CreatedAt = t.Format("2006-01-02 15:04:05")
	} else {
		music.CreatedAt = createdAt
	}
	
	return &music, nil
}

// DeleteMusic 删除音乐记录（同时删除歌词绑定记录）
func DeleteMusic(id, userID int) error {
	// 先获取文件路径
	var filePath string
	var coverPath string
	err := DB.QueryRow("SELECT file_path, cover_path FROM music WHERE id = ? AND user_id = ?", id, userID).Scan(&filePath, &coverPath)
	if err != nil {
		return err
	}
	
	// 开始事务
	tx, err := DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	
	// 1. 删除歌词绑定记录
	_, err = tx.Exec("DELETE FROM music_lyrics_binding WHERE music_id = ?", id)
	if err != nil {
		log.Printf("删除歌词绑定记录失败: %v", err)
		return err
	}
	log.Printf("歌词绑定记录删除成功: music_id=%d", id)
	
	// 2. 删除数据库记录
	_, err = tx.Exec("DELETE FROM music WHERE id = ? AND user_id = ?", id, userID)
	if err != nil {
		log.Printf("删除音乐记录失败: %v", err)
		return err
	}
	
	// 提交事务
	if err = tx.Commit(); err != nil {
		return err
	}
	
	// 3. 删除物理文件（在事务外执行，即使失败也不影响数据库一致性）
	if _, err := os.Stat(filePath); err == nil {
		if err := os.Remove(filePath); err != nil {
			log.Printf("删除音乐文件失败: %v", err)
			// 不返回错误，允许继续
		} else {
			log.Printf("音乐文件删除成功: %s", filePath)
		}
	}
	
	// 4. 删除封面图片（如果有）
	if coverPath != "" {
		if _, err := os.Stat(coverPath); err == nil {
			os.Remove(coverPath)
		}
	}
	
	log.Printf("音乐记录删除成功: id=%d, user_id=%d", id, userID)
	return nil
}

