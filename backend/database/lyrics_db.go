package database

import (
	"database/sql"
	"log"
	"os"
	"time"

	"backend/models"
)

// InitLyricsTable 初始化歌词表和关联表
func InitLyricsTable() error {
	// 创建歌词内容表（不再直接关联music_id）
	createLyricsTableSQL := `
	CREATE TABLE IF NOT EXISTS lyrics (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL,
		title TEXT NOT NULL,
		artist TEXT,
		content TEXT NOT NULL,
		file_path TEXT NOT NULL,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (user_id) REFERENCES users(id)
	);`

	_, err := DB.Exec(createLyricsTableSQL)
	if err != nil {
		return err
	}

	// 创建歌曲-歌词关联表（多首歌可以绑定同一个歌词，但每首歌只能绑定一个歌词）
	createBindingTableSQL := `
	CREATE TABLE IF NOT EXISTS music_lyrics_binding (
		music_id INTEGER PRIMARY KEY,
		lyrics_id INTEGER NOT NULL,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (music_id) REFERENCES music(id) ON DELETE CASCADE,
		FOREIGN KEY (lyrics_id) REFERENCES lyrics(id) ON DELETE CASCADE
	);`

	_, err = DB.Exec(createBindingTableSQL)
	if err != nil {
		return err
	}

	// 创建索引以提高搜索性能
	_, err = DB.Exec(`CREATE INDEX IF NOT EXISTS idx_lyrics_title_artist ON lyrics(title, artist);`)
	if err != nil {
		return err
	}

	_, err = DB.Exec(`CREATE INDEX IF NOT EXISTS idx_binding_lyrics_id ON music_lyrics_binding(lyrics_id);`)
	if err != nil {
		return err
	}

	log.Println("歌词表和关联表初始化成功")
	return nil
}

// SaveLyrics 保存歌词记录（不绑定到具体歌曲）
func SaveLyrics(lyrics *models.Lyrics) error {
	result, err := DB.Exec(
		`INSERT INTO lyrics (user_id, title, artist, content, file_path) 
		VALUES (?, ?, ?, ?, ?)`,
		lyrics.UserID, lyrics.Title, lyrics.Artist, lyrics.Content, lyrics.FilePath,
	)
	if err != nil {
		return err
	}

	id, err := result.LastInsertId()
	if err != nil {
		return err
	}
	lyrics.ID = int(id)
	lyrics.CreatedAt = time.Now()

	return nil
}

// GetLyricsByMusicID 根据音乐ID获取歌词（通过关联表查询）
func GetLyricsByMusicID(musicID int) (*models.Lyrics, error) {
	var lyrics models.Lyrics
	var createdAt string

	err := DB.QueryRow(
		`SELECT l.id, l.user_id, l.title, l.artist, l.content, l.file_path, l.created_at 
		FROM lyrics l
		INNER JOIN music_lyrics_binding b ON l.id = b.lyrics_id
		WHERE b.music_id = ?`,
		musicID,
	).Scan(
		&lyrics.ID,
		&lyrics.UserID,
		&lyrics.Title,
		&lyrics.Artist,
		&lyrics.Content,
		&lyrics.FilePath,
		&createdAt,
	)

	if err != nil {
		return nil, err
	}

	lyrics.MusicID = musicID // 设置音乐ID供返回使用

	// 解析时间
	if t, err := time.Parse(time.RFC3339, createdAt); err == nil {
		lyrics.CreatedAt = t
	}

	return &lyrics, nil
}

// GetLyricsByID 根据ID获取歌词
func GetLyricsByID(id int) (*models.Lyrics, error) {
	var lyrics models.Lyrics
	var createdAt string

	err := DB.QueryRow(
		`SELECT id, user_id, title, artist, content, file_path, created_at 
		FROM lyrics WHERE id = ?`,
		id,
	).Scan(
		&lyrics.ID,
		&lyrics.UserID,
		&lyrics.Title,
		&lyrics.Artist,
		&lyrics.Content,
		&lyrics.FilePath,
		&createdAt,
	)

	if err != nil {
		return nil, err
	}

	// 解析时间
	if t, err := time.Parse(time.RFC3339, createdAt); err == nil {
		lyrics.CreatedAt = t
	}

	return &lyrics, nil
}

// SearchLyrics 搜索歌词（按标题或艺术家）
func SearchLyrics(userID int, keyword string) ([]models.Lyrics, error) {
	query := `SELECT id, user_id, title, artist, content, file_path, created_at 
		FROM lyrics WHERE user_id = ? AND (title LIKE ? OR artist LIKE ?) 
		ORDER BY created_at DESC`

	searchPattern := "%" + keyword + "%"
	rows, err := DB.Query(query, userID, searchPattern, searchPattern)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var lyricsList []models.Lyrics
	for rows.Next() {
		var lyrics models.Lyrics
		var createdAt string

		err := rows.Scan(
			&lyrics.ID,
			&lyrics.UserID,
			&lyrics.Title,
			&lyrics.Artist,
			&lyrics.Content,
			&lyrics.FilePath,
			&createdAt,
		)
		if err != nil {
			log.Printf("扫描歌词记录失败: %v", err)
			continue
		}

		// 解析时间
		if t, err := time.Parse(time.RFC3339, createdAt); err == nil {
			lyrics.CreatedAt = t
		}

		lyricsList = append(lyricsList, lyrics)
	}

	return lyricsList, nil
}

// GetUserLyrics 获取用户的所有歌词
func GetUserLyrics(userID int) ([]models.Lyrics, error) {
	query := `SELECT id, user_id, title, artist, content, file_path, created_at 
		FROM lyrics WHERE user_id = ? ORDER BY created_at DESC`

	rows, err := DB.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var lyricsList []models.Lyrics
	for rows.Next() {
		var lyrics models.Lyrics
		var createdAt string

		err := rows.Scan(
			&lyrics.ID,
			&lyrics.UserID,
			&lyrics.Title,
			&lyrics.Artist,
			&lyrics.Content,
			&lyrics.FilePath,
			&createdAt,
		)
		if err != nil {
			log.Printf("扫描歌词记录失败: %v", err)
			continue
		}

		// 解析时间
		if t, err := time.Parse(time.RFC3339, createdAt); err == nil {
			lyrics.CreatedAt = t
		}

		lyricsList = append(lyricsList, lyrics)
	}

	return lyricsList, nil
}

// BindLyricsToMusic 将歌词绑定到音乐（使用关联表，每首歌只能绑定一个歌词，但多首歌可以绑定同一个歌词）
func BindLyricsToMusic(lyricsID, musicID, userID int) error {
	// 检查歌词是否属于当前用户
	var ownerID int
	err := DB.QueryRow("SELECT user_id FROM lyrics WHERE id = ?", lyricsID).Scan(&ownerID)
	if err != nil {
		return err
	}

	if ownerID != userID {
		return sql.ErrNoRows
	}

	// 开始事务
	tx, err := DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// 先删除该歌曲之前的歌词绑定（一首歌只能绑定一个歌词）
	_, err = tx.Exec("DELETE FROM music_lyrics_binding WHERE music_id = ?", musicID)
	if err != nil {
		return err
	}

	// 插入新的绑定关系
	_, err = tx.Exec("INSERT INTO music_lyrics_binding (music_id, lyrics_id) VALUES (?, ?)", musicID, lyricsID)
	if err != nil {
		return err
	}

	// 提交事务
	return tx.Commit()
}

// UnbindLyricsFromMusic 解除歌词与音乐的绑定
func UnbindLyricsFromMusic(musicID int) error {
	_, err := DB.Exec("DELETE FROM music_lyrics_binding WHERE music_id = ?", musicID)
	return err
}

// DeleteLyrics 删除歌词
func DeleteLyrics(id, userID int) error {
	// 先获取文件路径
	var filePath string
	err := DB.QueryRow("SELECT file_path FROM lyrics WHERE id = ? AND user_id = ?", id, userID).Scan(&filePath)
	if err != nil {
		return err
	}

	// 删除物理文件
	if _, err := os.Stat(filePath); err == nil {
		if err := os.Remove(filePath); err != nil {
			log.Printf("删除歌词文件失败: %v", err)
			return err
		}
		log.Printf("歌词文件删除成功: %s", filePath)
	}

	// 删除数据库记录
	_, err = DB.Exec("DELETE FROM lyrics WHERE id = ? AND user_id = ?", id, userID)
	if err != nil {
		log.Printf("删除歌词记录失败: %v", err)
		return err
	}

	log.Printf("歌词记录删除成功: id=%d, user_id=%d", id, userID)
	return nil
}
