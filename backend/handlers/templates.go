package handlers

import (
	"embed"
	"html/template"
	"io/fs"
)

//go:embed templates/*
var templatesFS embed.FS

// getTemplate 从嵌入的文件系统中获取模板
func getTemplate(name string) (*template.Template, error) {
	// 从 embed.FS 中获取 templates 子目录
	fsys, err := fs.Sub(templatesFS, "templates")
	if err != nil {
		// 如果出错，尝试直接从根目录读取
		fsys = templatesFS
	}

	// 读取模板文件内容
	content, err := fs.ReadFile(fsys, name)
	if err != nil {
		return nil, err
	}

	// 解析模板
	tmpl, err := template.New(name).Parse(string(content))
	if err != nil {
		return nil, err
	}

	return tmpl, nil
}
