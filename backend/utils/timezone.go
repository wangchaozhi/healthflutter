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

// GetShanghaiTZ 获取上海时区
func GetShanghaiTZ() *time.Location {
	return shanghaiTZ
}

// NowUTC 获取当前 UTC 时间（用于存储）
func NowUTC() time.Time {
	return time.Now().UTC()
}

// NowUTCString 获取当前 UTC 时间字符串（格式: 2006-01-02 15:04:05，用于存储）
func NowUTCString() string {
	return NowUTC().Format("2006-01-02 15:04:05")
}

// UTCToShanghai 将 UTC 时间字符串转换为上海时间字符串
func UTCToShanghai(utcTimeStr string) string {
	if utcTimeStr == "" {
		return ""
	}
	
	// 尝试解析多种格式
	var t time.Time
	var err error
	
	// 尝试 RFC3339 格式
	if t, err = time.Parse(time.RFC3339, utcTimeStr); err == nil {
		return t.In(shanghaiTZ).Format("2006-01-02 15:04:05")
	}
	
	// 尝试标准格式 (假设是 UTC)
	if t, err = time.Parse("2006-01-02 15:04:05", utcTimeStr); err == nil {
		utcTime := time.Date(t.Year(), t.Month(), t.Day(), t.Hour(), t.Minute(), t.Second(), 0, time.UTC)
		return utcTime.In(shanghaiTZ).Format("2006-01-02 15:04:05")
	}
	
	// 如果解析失败，返回原字符串
	return utcTimeStr
}
