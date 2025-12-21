package models

import "time"

// Lyrics 歌词信息
type Lyrics struct {
	ID        int       `json:"id"`
	MusicID   int       `json:"music_id"`   // 绑定的音乐ID（可为空）
	UserID    int       `json:"user_id"`    // 上传者ID
	Title     string    `json:"title"`      // 歌曲名称
	Artist    string    `json:"artist"`     // 艺术家
	Content   string    `json:"content"`    // 歌词内容（LRC格式）
	FilePath  string    `json:"file_path"`  // 歌词文件路径
	CreatedAt time.Time `json:"created_at"`
}

// LyricsUploadResponse 歌词上传响应
type LyricsUploadResponse struct {
	Success bool    `json:"success"`
	Message string  `json:"message"`
	Lyrics  *Lyrics `json:"lyrics,omitempty"`
}

// LyricsListResponse 歌词列表响应
type LyricsListResponse struct {
	Success bool     `json:"success"`
	Message string   `json:"message"`
	List    []Lyrics `json:"list,omitempty"`
	Total   int      `json:"total"`
}

// LyricsBindRequest 歌词绑定请求
type LyricsBindRequest struct {
	MusicID  int `json:"music_id"`
	LyricsID int `json:"lyrics_id"`
}

// LyricsBindResponse 歌词绑定响应
type LyricsBindResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

// LyricsSearchRequest 歌词搜索请求
type LyricsSearchRequest struct {
	Keyword string `json:"keyword"`
}
