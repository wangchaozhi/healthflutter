package models

import "time"

// MusicShare 音乐分享记录
type MusicShare struct {
	ID          int       `json:"id"`
	UserID      int       `json:"user_id"`
	MusicID     int       `json:"music_id"`
	ShareToken  string    `json:"share_token"`  // 唯一分享标识
	Title       string    `json:"title"`
	Artist      string    `json:"artist"`
	ViewCount   int       `json:"view_count"`    // 访问次数
	CreatedAt   time.Time `json:"created_at"`
	ExpiresAt   *time.Time `json:"expires_at,omitempty"` // 过期时间（可选）
}

// MusicShareResponse 分享响应
type MusicShareResponse struct {
	Success bool        `json:"success"`
	Message string      `json:"message"`
	Share   *MusicShare `json:"share,omitempty"`
	ShareURL string     `json:"share_url,omitempty"`
}

// MusicShareListResponse 分享列表响应
type MusicShareListResponse struct {
	Success bool          `json:"success"`
	Message string        `json:"message"`
	List    []MusicShare  `json:"list,omitempty"`
}

// MusicShareDetailResponse 分享详情响应（公开访问）
type MusicShareDetailResponse struct {
	Success   bool   `json:"success"`
	Message   string `json:"message"`
	MusicID   int    `json:"music_id,omitempty"`
	Title     string `json:"title,omitempty"`
	Artist    string `json:"artist,omitempty"`
	Album     string `json:"album,omitempty"`
	StreamURL string `json:"stream_url,omitempty"`
}

