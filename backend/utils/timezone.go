package utils

import (
	"time"
)

var (
	// 东八区时区
	shanghaiTZ *time.Location
)

func init() {
	var err error
	shanghaiTZ, err = time.LoadLocation("Asia/Shanghai")
	if err != nil {
		// 如果加载失败，使用固定偏移量（UTC+8）
		shanghaiTZ = time.FixedZone("CST", 8*60*60)
	}
}

// Now 获取当前东八区时间
func Now() time.Time {
	return time.Now().In(shanghaiTZ)
}

// NowString 获取当前东八区时间字符串（格式: 2006-01-02 15:04:05）
func NowString() string {
	return Now().Format("2006-01-02 15:04:05")
}

// NowTimestamp 获取当前东八区时间戳字符串（格式: 20060102150405）
func NowTimestamp() string {
	return Now().Format("20060102150405")
}
