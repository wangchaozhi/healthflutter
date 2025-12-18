package models

// 抖音解析请求
type DouyinParsingRequest struct {
	Text string `json:"text"`
}

// 抖音解析响应
type DouyinParsingResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Data    string `json:"data,omitempty"`
}

// 抖音文件信息
type DouyinFile struct {
	ID           int    `json:"id"`
	UserID       int    `json:"user_id"`
	URL          string `json:"url,omitempty"` // 解析的URL
	FileName     string `json:"file_name"`
	FileSize     int64  `json:"file_size"`
	FileSizeStr  string `json:"file_size_str"` // 格式化后的文件大小
	ModifiedTime string `json:"modified_time"`
	Path         string `json:"path"`
	CreatedAt    string `json:"created_at"`
}

// 抖音文件列表响应
type DouyinFileListResponse struct {
	Success bool         `json:"success"`
	Message string       `json:"message"`
	List    []DouyinFile `json:"list,omitempty"`
}

// 下载请求
type DouyinDownloadRequest struct {
	ID   int    `json:"id"`
	Path string `json:"path"`
}

