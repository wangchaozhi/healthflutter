package services

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"time"

	"backend/database"
	"backend/models"
)

// 提取URL
func ExtractURL(text string) (string, error) {
	urlRegex := regexp.MustCompile(`(https?://[\w./?=&%-]+)`)
	matches := urlRegex.FindStringSubmatch(text)
	if len(matches) == 0 {
		return "", fmt.Errorf("未解析到正确链接")
	}
	return matches[0], nil
}

// Linux解析
func LinuxParsing(url string) (*models.DouyinParsingResponse, error) {
	// 构建f2命令
	f2Cmd := fmt.Sprintf("f2 dy -M one -u %s -n {nickname}_{create}", url)
	// 使用conda run命令，在douyi_download环境中执行
	cmdStr := fmt.Sprintf("/root/miniconda3/bin/conda run -n douyi_download %s", f2Cmd)
	cmd := exec.Command("/bin/bash", "-c", cmdStr)

	// 清除代理环境变量
	cmd.Env = os.Environ()
	newEnv := []string{}
	for _, env := range cmd.Env {
		if !strings.HasPrefix(env, "http_proxy=") &&
			!strings.HasPrefix(env, "https_proxy=") &&
			!strings.HasPrefix(env, "HTTP_PROXY=") &&
			!strings.HasPrefix(env, "HTTPS_PROXY=") {
			newEnv = append(newEnv, env)
		}
	}
	newEnv = append(newEnv, "PYTHONIOENCODING=utf-8")
	cmd.Env = newEnv

	output, err := cmd.CombinedOutput()
	outputStr := string(output)

	// 即使退出码不是0，只要输出中包含"当前任务处理完成"就认为成功
	if strings.Contains(outputStr, "当前任务处理完成") {
		return &models.DouyinParsingResponse{
			Success: true,
			Message: "解析成功",
			Data:    url,
		}, nil
	}

	// 如果输出中没有成功标识，返回错误
	if err != nil {
		return nil, fmt.Errorf("执行命令失败: %v, 输出: %s", err, outputStr)
	}

	return &models.DouyinParsingResponse{
		Success: false,
		Message: "执行命令失败，未找到完成标识",
	}, nil
}

// Windows解析
func WindowsParsing(url string) (*models.DouyinParsingResponse, error) {
	// 直接使用conda命令，假设conda已在PATH中
	// 构建f2命令，注意引号的处理：在Windows cmd中，外层用单引号或不用引号，内层用双引号
	f2Cmd := fmt.Sprintf(`f2 dy -M one -u %s -n {nickname}_{create}`, url)

	// 使用conda run命令，这是更现代和可靠的方式
	cmdStr := fmt.Sprintf(`conda run -n douyi_download %s`, f2Cmd)
	cmd := exec.Command("cmd.exe", "/c", cmdStr)

	// 清除代理环境变量
	cmd.Env = os.Environ()
	newEnv := []string{}
	for _, env := range cmd.Env {
		if !strings.HasPrefix(env, "http_proxy=") &&
			!strings.HasPrefix(env, "https_proxy=") &&
			!strings.HasPrefix(env, "HTTP_PROXY=") &&
			!strings.HasPrefix(env, "HTTPS_PROXY=") {
			newEnv = append(newEnv, env)
		}
	}
	newEnv = append(newEnv, "PYTHONIOENCODING=utf-8")
	cmd.Env = newEnv

	output, err := cmd.CombinedOutput()
	outputStr := string(output)

	// 即使退出码不是0，只要输出中包含"当前任务处理完成"就认为成功
	if strings.Contains(outputStr, "当前任务处理完成") {
		return &models.DouyinParsingResponse{
			Success: true,
			Message: "解析成功",
			Data:    url,
		}, nil
	}

	// 如果输出中没有成功标识，返回错误
	if err != nil {
		return nil, fmt.Errorf("执行命令失败: %v, 输出: %s", err, outputStr)
	}

	return &models.DouyinParsingResponse{
		Success: false,
		Message: "执行命令失败，未找到完成标识",
	}, nil
}

// 解析抖音链接
func ParseDouyinURL(text string) (*models.DouyinParsingResponse, error) {
	url, err := ExtractURL(text)
	if err != nil {
		return nil, err
	}

	if runtime.GOOS == "windows" {
		return WindowsParsing(url)
	} else if runtime.GOOS == "linux" {
		return LinuxParsing(url)
	}

	return nil, fmt.Errorf("不支持的操作系统")
}

// 扫描下载目录并保存文件信息到数据库
// 只保存最近下载的文件（通过文件修改时间判断）
func ScanAndSaveFiles(userID int, url string) error {
	// f2默认下载路径：Download/douyin/one/{nickname}/
	downloadPath := "Download/douyin/one"

	// 获取当前时间，只处理最近5分钟内修改的文件（新下载的文件）
	cutoffTime := time.Now().Add(-5 * time.Minute)

	return filepath.Walk(downloadPath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil // 忽略错误，继续扫描
		}

		// 只处理视频文件
		if !info.IsDir() && isVideoFile(path) {
			// 只处理最近修改的文件（新下载的文件）
			if info.ModTime().Before(cutoffTime) {
				return nil // 文件太旧，跳过
			}

			// 检查该用户是否已有此文件记录（且URL匹配）
			exists, err := database.FileExistsWithURL(userID, path, url)
			if err != nil {
				return nil // 忽略错误
			}
			if exists {
				return nil // 该用户已存在此文件记录，跳过
			}

			// 保存文件信息（包含URL）
			file := models.DouyinFile{
				UserID:       userID,
				URL:          url,
				FileName:     info.Name(),
				FileSize:     info.Size(),
				FileSizeStr:  formatFileSize(info.Size()),
				ModifiedTime: info.ModTime().Format("2006-01-02 15:04:05"),
				Path:         path,
				CreatedAt:    time.Now().Format("2006-01-02 15:04:05"),
			}

			return database.SaveDouyinFile(&file)
		}

		return nil
	})
}

// 判断是否为视频文件
func isVideoFile(path string) bool {
	ext := strings.ToLower(filepath.Ext(path))
	videoExts := []string{".mp4", ".avi", ".mov", ".mkv", ".flv", ".wmv", ".webm"}
	for _, v := range videoExts {
		if ext == v {
			return true
		}
	}
	return false
}

// 格式化文件大小
func formatFileSize(size int64) string {
	const unit = 1024
	if size < unit {
		return fmt.Sprintf("%d B", size)
	}
	div, exp := int64(unit), 0
	for n := size / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(size)/float64(div), "KMGTPE"[exp])
}
