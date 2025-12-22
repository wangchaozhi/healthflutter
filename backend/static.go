package main

import (
	"embed"
	"io"
	"io/fs"
	"net/http"
	"path/filepath"
	"strconv"
	"strings"
)

//go:embed ariang/*
var ariangFS embed.FS

//go:embed templates/*
var templatesFS embed.FS

// ariangHandler 处理 AriaNg 静态文件服务
// 支持客户端路由：所有非文件请求都返回 index.html
func ariangHandler() http.Handler {
	// 从 embed.FS 中获取 ariang 子目录
	fsys, err := fs.Sub(ariangFS, "ariang")
	if err != nil {
		// 如果出错，返回空文件系统
		return http.NotFoundHandler()
	}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// 移除 /ariang/ 前缀
		path := strings.TrimPrefix(r.URL.Path, "/ariang/")
		if path == "" {
			path = "index.html"
		}

		// 尝试打开文件
		file, err := fsys.Open(path)
		if err != nil {
			// 文件不存在，返回 index.html（支持客户端路由）
			indexFile, err := fsys.Open("index.html")
			if err != nil {
				http.NotFound(w, r)
				return
			}
			defer indexFile.Close()
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			io.Copy(w, indexFile)
			return
		}
		defer file.Close()

		// 检查文件信息
		info, err := file.Stat()
		if err != nil {
			http.NotFound(w, r)
			return
		}

		// 如果是目录，返回 index.html
		if info.IsDir() {
			indexFile, err := fsys.Open("index.html")
			if err != nil {
				http.NotFound(w, r)
				return
			}
			defer indexFile.Close()
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			io.Copy(w, indexFile)
			return
		}

		// 设置正确的 Content-Type
		ext := filepath.Ext(path)
		setContentType(w, ext)

		// 设置 Content-Length（如果可用）
		if size := info.Size(); size >= 0 {
			w.Header().Set("Content-Length", strconv.FormatInt(size, 10))
		}

		// 服务文件
		io.Copy(w, file)
	})
}

// setContentType 根据文件扩展名设置 Content-Type
func setContentType(w http.ResponseWriter, ext string) {
	switch ext {
	case ".html":
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
	case ".css":
		w.Header().Set("Content-Type", "text/css; charset=utf-8")
	case ".js":
		w.Header().Set("Content-Type", "application/javascript; charset=utf-8")
	case ".json":
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
	case ".png":
		w.Header().Set("Content-Type", "image/png")
	case ".ico":
		w.Header().Set("Content-Type", "image/x-icon")
	case ".woff":
		w.Header().Set("Content-Type", "font/woff")
	case ".woff2":
		w.Header().Set("Content-Type", "font/woff2")
	case ".ttf":
		w.Header().Set("Content-Type", "font/ttf")
	case ".eot":
		w.Header().Set("Content-Type", "application/vnd.ms-fontobject")
	case ".svg":
		w.Header().Set("Content-Type", "image/svg+xml")
	case ".txt":
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	default:
		w.Header().Set("Content-Type", "application/octet-stream")
	}
}

// GetTemplateFS 获取嵌入的模板文件系统
func GetTemplateFS() fs.FS {
	fsys, err := fs.Sub(templatesFS, "templates")
	if err != nil {
		// 如果出错，返回原始文件系统
		return templatesFS
	}
	return fsys
}
