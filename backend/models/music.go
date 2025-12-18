package models

// Music 音乐信息
type Music struct {
	ID          int    `json:"id"`
	UserID      int    `json:"user_id"`
	Title       string `json:"title"`        // 歌曲名称
	Artist      string `json:"artist"`       // 艺术家
	Album       string `json:"album"`        // 专辑
	FilePath    string `json:"file_path"`    // 文件路径
	FileSize    int64  `json:"file_size"`    // 文件大小
	FileSizeStr string `json:"file_size_str"` // 格式化的文件大小
	Duration    int    `json:"duration"`     // 时长（秒）
	FileType    string `json:"file_type"`    // 文件类型 (mp3, flac, etc)
	CoverPath   string `json:"cover_path"`   // 封面图片路径
	CreatedAt   string `json:"created_at"`
}

// MusicUploadResponse 音乐上传响应
type MusicUploadResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Music   *Music `json:"music,omitempty"`
}

// MusicListResponse 音乐列表响应
type MusicListResponse struct {
	Success     bool    `json:"success"`
	Message     string  `json:"message"`
	List        []Music `json:"list,omitempty"`
	CurrentPage int     `json:"currentPage"`
	TotalPages  int     `json:"totalPages"`
	Total       int     `json:"total"`
}

