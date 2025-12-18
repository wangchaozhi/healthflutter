package models

// 文件传输记录
type FileTransfer struct {
	ID          int    `json:"id"`
	UserID      int    `json:"user_id"`
	FileName    string `json:"file_name"`
	FilePath    string `json:"file_path"`
	FileSize    int64  `json:"file_size"`
	FileSizeStr string `json:"file_size_str"`
	FileType    string `json:"file_type"`
	CreatedAt   string `json:"created_at"`
}

// 文件传输列表响应
type FileTransferListResponse struct {
	Success bool          `json:"success"`
	Message string        `json:"message"`
	Data    FileListData  `json:"data,omitempty"`
}

// 文件列表数据
type FileListData struct {
	List     []FileTransfer `json:"list"`
	Total    int            `json:"total"`
	Page     int            `json:"page"`
	PageSize int            `json:"page_size"`
}

// 文件上传响应
type FileUploadResponse struct {
	Success bool        `json:"success"`
	Message string      `json:"message"`
	Data    FileTransfer `json:"data,omitempty"`
}

