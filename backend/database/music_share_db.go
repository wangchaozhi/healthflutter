package database

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"log"
	"time"

	"backend/models"
	"backend/utils"
)

// InitMusicShareTable 初始化音乐分享表
func InitMusicShareTable() error {
	createTableSQL := `
	CREATE TABLE IF NOT EXISTS music_shares (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL,
		music_id INTEGER NOT NULL,
		share_token TEXT NOT NULL UNIQUE,
		view_count INTEGER DEFAULT 0,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		expires_at DATETIME,
		FOREIGN KEY (user_id) REFERENCES users(id),
		FOREIGN KEY (music_id) REFERENCES music(id) ON DELETE CASCADE
	);`

	_, err := DB.Exec(createTableSQL)
	if err != nil {
		return err
	}

	log.Println("音乐分享表初始化成功")
	return nil
}

// GenerateShareToken 生成唯一的分享token
func GenerateShareToken() (string, error) {
	bytes := make([]byte, 16)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}

// CreateMusicShare 创建音乐分享
func CreateMusicShare(userID, musicID int) (*models.MusicShare, error) {
	// 检查是否已经分享过
	var existingID int
	err := DB.QueryRow(
		"SELECT id FROM music_shares WHERE user_id = ? AND music_id = ?",
		userID, musicID,
	).Scan(&existingID)
	
	if err == nil {
		// 已存在，返回现有的分享
		return GetMusicShareByID(existingID, userID)
	}

	// 生成唯一token
	token, err := GenerateShareToken()
	if err != nil {
		return nil, err
	}

	// 插入分享记录
	result, err := DB.Exec(
		"INSERT INTO music_shares (user_id, music_id, share_token) VALUES (?, ?, ?)",
		userID, musicID, token,
	)
	if err != nil {
		return nil, err
	}

	shareID, _ := result.LastInsertId()
	return GetMusicShareByID(int(shareID), userID)
}

// GetMusicShareByID 根据ID获取分享信息
func GetMusicShareByID(id, userID int) (*models.MusicShare, error) {
	var share models.MusicShare
	var createdAt string
	var expiresAt sql.NullString

	err := DB.QueryRow(
		`SELECT ms.id, ms.user_id, ms.music_id, ms.share_token, ms.view_count, ms.created_at, ms.expires_at,
		m.title, m.artist
		FROM music_shares ms
		JOIN music m ON ms.music_id = m.id
		WHERE ms.id = ? AND ms.user_id = ?`,
		id, userID,
	).Scan(
		&share.ID, &share.UserID, &share.MusicID, &share.ShareToken,
		&share.ViewCount, &createdAt, &expiresAt,
		&share.Title, &share.Artist,
	)

	if err != nil {
		return nil, err
	}

	// 解析时间
	if t, err := time.Parse(time.RFC3339, createdAt); err == nil {
		share.CreatedAt = t
	}
	if expiresAt.Valid && expiresAt.String != "" {
		if t, err := time.Parse(time.RFC3339, expiresAt.String); err == nil {
			share.ExpiresAt = &t
		}
	}

	return &share, nil
}

// GetMusicShareByToken 通过token获取分享信息（公开访问）
func GetMusicShareByToken(token string) (*models.MusicShare, error) {
	var share models.MusicShare
	var createdAt string
	var expiresAt sql.NullString

	err := DB.QueryRow(
		`SELECT ms.id, ms.user_id, ms.music_id, ms.share_token, ms.view_count, ms.created_at, ms.expires_at,
		m.title, m.artist
		FROM music_shares ms
		JOIN music m ON ms.music_id = m.id
		WHERE ms.share_token = ?`,
		token,
	).Scan(
		&share.ID, &share.UserID, &share.MusicID, &share.ShareToken,
		&share.ViewCount, &createdAt, &expiresAt,
		&share.Title, &share.Artist,
	)

	if err != nil {
		return nil, err
	}

	// 解析时间
	if t, err := time.Parse(time.RFC3339, createdAt); err == nil {
		share.CreatedAt = t
	}
	if expiresAt.Valid && expiresAt.String != "" {
		if t, err := time.Parse(time.RFC3339, expiresAt.String); err == nil {
			share.ExpiresAt = &t
		}
	}

	// 检查是否过期（使用 UTC 时间比较）
	if share.ExpiresAt != nil && share.ExpiresAt.Before(utils.NowUTC()) {
		return nil, nil // 已过期
	}

	return &share, nil
}

// GetUserMusicShares 获取用户的所有分享
func GetUserMusicShares(userID int) ([]models.MusicShare, error) {
	rows, err := DB.Query(
		`SELECT ms.id, ms.user_id, ms.music_id, ms.share_token, ms.view_count, ms.created_at, ms.expires_at,
		m.title, m.artist
		FROM music_shares ms
		JOIN music m ON ms.music_id = m.id
		WHERE ms.user_id = ?
		ORDER BY ms.created_at DESC`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var shares []models.MusicShare
	for rows.Next() {
		var share models.MusicShare
		var createdAt string
		var expiresAt sql.NullString

		err := rows.Scan(
			&share.ID, &share.UserID, &share.MusicID, &share.ShareToken,
			&share.ViewCount, &createdAt, &expiresAt,
			&share.Title, &share.Artist,
		)
		if err != nil {
			log.Printf("扫描分享记录失败: %v", err)
			continue
		}

		// 解析时间
		if t, err := time.Parse(time.RFC3339, createdAt); err == nil {
			share.CreatedAt = t
		}
		if expiresAt.Valid && expiresAt.String != "" {
			if t, err := time.Parse(time.RFC3339, expiresAt.String); err == nil {
				share.ExpiresAt = &t
			}
		}

		shares = append(shares, share)
	}

	return shares, nil
}

// DeleteMusicShare 删除分享
func DeleteMusicShare(id, userID int) error {
	result, err := DB.Exec(
		"DELETE FROM music_shares WHERE id = ? AND user_id = ?",
		id, userID,
	)
	if err != nil {
		return err
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return nil // 没有找到记录
	}

	log.Printf("删除分享成功: id=%d, user_id=%d", id, userID)
	return nil
}

// IncrementShareViewCount 增加分享访问次数
func IncrementShareViewCount(token string) error {
	_, err := DB.Exec(
		"UPDATE music_shares SET view_count = view_count + 1 WHERE share_token = ?",
		token,
	)
	return err
}

