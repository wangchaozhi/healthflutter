package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"backend/database"
	"backend/handlers"
	"backend/utils"
	"golang.org/x/crypto/bcrypt"
)

type User struct {
	ID       int    `json:"id"`
	Username string `json:"username"`
	Password string `json:"password,omitempty"`
}

type RegisterRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type LoginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type AuthResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Token   string `json:"token,omitempty"`
	User    *User  `json:"user,omitempty"`
}

// 健康活动记录
type HealthActivity struct {
	ID         int    `json:"id"`
	UserID     int    `json:"user_id"`
	RecordDate string `json:"record_date"` // 格式: YYYY-MM-DD
	RecordTime string `json:"record_time"` // 格式: HH:mm
	WeekDay    string `json:"week_day"`    // 星期几
	Duration   int    `json:"duration"`    // 持续时间（分钟）
	Remark     string `json:"remark"`      // 备注
	Tag        string `json:"tag"`         // 标签: auto=自动, manual=手动
	CreatedAt  string `json:"created_at"`
}

type CreateActivityRequest struct {
	RecordDate string `json:"record_date"`
	RecordTime string `json:"record_time"`
	Duration   int    `json:"duration"`
	Remark     string `json:"remark"`
	Tag        string `json:"tag"` // 标签: auto=自动, manual=手动
}

type ActivityResponse struct {
	Success bool             `json:"success"`
	Message string           `json:"message"`
	Data    *HealthActivity  `json:"data,omitempty"`
	List    []HealthActivity `json:"list,omitempty"`
	Stats   *ActivityStats   `json:"stats,omitempty"`
}

type ActivityStats struct {
	TotalAuto              int      `json:"total_auto"`               // 总计自动次数
	TotalManual            int      `json:"total_manual"`             // 总计手动次数
	YearAuto               int      `json:"year_auto"`                // 今年自动次数
	YearManual             int      `json:"year_manual"`              // 今年手动次数
	MonthAuto              int      `json:"month_auto"`               // 本月自动次数
	MonthManual            int      `json:"month_manual"`             // 本月手动次数
	AutoFrequencyPerDay    float64  `json:"auto_frequency_per_day"`   // 自动频率（次/天）
	ManualFrequencyPerDay  float64  `json:"manual_frequency_per_day"` // 手动频率（次/天）
	TotalFrequencyPerDay   float64  `json:"total_frequency_per_day"`  // 总频率（次/天）
	AutoPeriodDays         float64  `json:"auto_period_days"`         // 自动周期（天/次）
	ManualPeriodDays       float64  `json:"manual_period_days"`       // 手动周期（天/次）
	TotalPeriodDays        float64  `json:"total_period_days"`        // 总周期（天/次）
	EarliestDate           string   `json:"earliest_date"`            // 最早记录日期
	LastTwoInterval        int      `json:"last_two_interval"`        // 最后两次间隔天数，-1表示不足2条
	LastTwoAutoInterval    int      `json:"last_two_auto_interval"`   // 最后两个自动间隔天数
	LastTwoManualInterval  int      `json:"last_two_manual_interval"` // 最后两个手动间隔天数
	LastIntervalDays       *float64 `json:"last_interval_days,omitempty"`        // 最后两次间隔天数（小数）
	LastAutoIntervalDays   *float64 `json:"last_auto_interval_days,omitempty"`   // 最后两次自动间隔天数（小数）
	LastManualIntervalDays *float64 `json:"last_manual_interval_days,omitempty"` // 最后两次手动间隔天数（小数）
	LastToNowDays          *float64 `json:"last_to_now_days,omitempty"`          // 最后一次距今天数（小数）
}

func initDB() {
	if err := database.InitDB("./health.db"); err != nil {
		log.Fatal("数据库初始化失败:", err)
	}
}

func hashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	return string(bytes), err
}

func checkPasswordHash(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

// generateToken 已移至 handlers.GenerateToken

func registerHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	var req RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "无效的请求数据", http.StatusBadRequest)
		return
	}

	// 验证输入
	if req.Username == "" || req.Password == "" {
		json.NewEncoder(w).Encode(AuthResponse{
			Success: false,
			Message: "用户名和密码不能为空",
		})
		return
	}

	if len(req.Password) < 6 {
		json.NewEncoder(w).Encode(AuthResponse{
			Success: false,
			Message: "密码长度至少6位",
		})
		return
	}

	// 检查用户名是否已存在
	var existingID int
	err := database.DB.QueryRow("SELECT id FROM users WHERE username = ?", req.Username).Scan(&existingID)
	if err == nil {
		json.NewEncoder(w).Encode(AuthResponse{
			Success: false,
			Message: "用户名已存在",
		})
		return
	}

	// 加密密码
	hashedPassword, err := hashPassword(req.Password)
	if err != nil {
		http.Error(w, "密码加密失败", http.StatusInternalServerError)
		return
	}

	// 插入新用户
	result, err := database.DB.Exec("INSERT INTO users (username, password) VALUES (?, ?)", req.Username, hashedPassword)
	if err != nil {
		http.Error(w, "注册失败", http.StatusInternalServerError)
		return
	}

	userID, _ := result.LastInsertId()

	// 生成token
	token, err := handlers.GenerateToken(req.Username, int(userID))
	if err != nil {
		http.Error(w, "Token生成失败", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(AuthResponse{
		Success: true,
		Message: "注册成功",
		Token:   token,
		User: &User{
			ID:       int(userID),
			Username: req.Username,
		},
	})
}

func loginHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	var req LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "无效的请求数据", http.StatusBadRequest)
		return
	}

	// 验证输入
	if req.Username == "" || req.Password == "" {
		json.NewEncoder(w).Encode(AuthResponse{
			Success: false,
			Message: "用户名和密码不能为空",
		})
		return
	}

	// 查询用户
	var userID int
	var hashedPassword string
	err := database.DB.QueryRow("SELECT id, password FROM users WHERE username = ?", req.Username).Scan(&userID, &hashedPassword)
	if err != nil {
		json.NewEncoder(w).Encode(AuthResponse{
			Success: false,
			Message: "用户名或密码错误",
		})
		return
	}

	// 验证密码
	if !checkPasswordHash(req.Password, hashedPassword) {
		json.NewEncoder(w).Encode(AuthResponse{
			Success: false,
			Message: "用户名或密码错误",
		})
		return
	}

	// 生成token
	token, err := handlers.GenerateToken(req.Username, userID)
	if err != nil {
		http.Error(w, "Token生成失败", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(AuthResponse{
		Success: true,
		Message: "登录成功",
		Token:   token,
		User: &User{
			ID:       userID,
			Username: req.Username,
		},
	})
}

// authMiddleware 使用handlers包中的AuthMiddleware
var authMiddleware = handlers.AuthMiddleware

func profileHandler(w http.ResponseWriter, r *http.Request) {
	userID := r.Header.Get("X-User-ID")

	var user User
	err := database.DB.QueryRow("SELECT id, username FROM users WHERE id = ?", userID).Scan(&user.ID, &user.Username)
	if err != nil {
		http.Error(w, "用户不存在", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(AuthResponse{
		Success: true,
		Message: "获取成功",
		User:    &user,
	})
}

// 获取星期几
func getWeekDay(dateStr string) string {
	t, err := time.Parse("2006-01-02", dateStr)
	if err != nil {
		return ""
	}
	weekdays := []string{"星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"}
	return weekdays[t.Weekday()]
}

// 创建健康活动记录
func createActivityHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	var req CreateActivityRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "无效的请求数据", http.StatusBadRequest)
		return
	}

	// 验证输入
	if req.RecordDate == "" || req.RecordTime == "" {
		json.NewEncoder(w).Encode(ActivityResponse{
			Success: false,
			Message: "记录日期和时间不能为空",
		})
		return
	}

	if req.Duration <= 0 {
		json.NewEncoder(w).Encode(ActivityResponse{
			Success: false,
			Message: "持续时间必须大于0",
		})
		return
	}

	weekDay := getWeekDay(req.RecordDate)
	if weekDay == "" {
		json.NewEncoder(w).Encode(ActivityResponse{
			Success: false,
			Message: "日期格式错误，应为 YYYY-MM-DD",
		})
		return
	}

	// 默认手动
	tag := req.Tag
	if tag != "auto" && tag != "manual" {
		tag = "manual"
	}

	var userIDInt int
	fmt.Sscanf(userID, "%d", &userIDInt)

	// 插入记录，存储 UTC 时间
	createdAtUTC := utils.NowUTCString()
	result, err := database.DB.Exec(
		"INSERT INTO health_activities (user_id, record_date, record_time, week_day, duration, remark, tag, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
		userIDInt, req.RecordDate, req.RecordTime, weekDay, req.Duration, req.Remark, tag, createdAtUTC,
	)
	if err != nil {
		http.Error(w, "创建记录失败", http.StatusInternalServerError)
		return
	}

	activityID, _ := result.LastInsertId()

	// 显示时转换为东八区时间
	activity := HealthActivity{
		ID:         int(activityID),
		UserID:     userIDInt,
		RecordDate: req.RecordDate,
		RecordTime: req.RecordTime,
		WeekDay:    weekDay,
		Duration:   req.Duration,
		Remark:     req.Remark,
		Tag:        tag,
		CreatedAt:  utils.UTCToShanghai(createdAtUTC), // 转换为东八区显示
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(ActivityResponse{
		Success: true,
		Message: "创建成功",
		Data:    &activity,
	})
}

// 获取健康活动记录列表
func listActivitiesHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	var userIDInt int
	fmt.Sscanf(userID, "%d", &userIDInt)

	rows, err := database.DB.Query(
		"SELECT id, user_id, record_date, record_time, week_day, duration, remark, COALESCE(tag, 'manual'), created_at FROM health_activities WHERE user_id = ? ORDER BY record_date DESC, record_time DESC LIMIT 5",
		userIDInt,
	)
	if err != nil {
		http.Error(w, "查询失败", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var activities []HealthActivity
	for rows.Next() {
		var activity HealthActivity
		var createdAt string
		err := rows.Scan(
			&activity.ID,
			&activity.UserID,
			&activity.RecordDate,
			&activity.RecordTime,
			&activity.WeekDay,
			&activity.Duration,
			&activity.Remark,
			&activity.Tag,
			&createdAt,
		)
		if err != nil {
			continue
		}

		// 处理 created_at 时间：数据库存储的是 UTC，显示时转换为东八区
		activity.CreatedAt = utils.UTCToShanghai(createdAt)

		activities = append(activities, activity)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(ActivityResponse{
		Success: true,
		Message: "获取成功",
		List:    activities,
	})
}

// 删除健康活动记录
func deleteActivityHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	// 从URL路径获取ID
	path := strings.TrimPrefix(r.URL.Path, "/api/activities/")
	var activityID int
	fmt.Sscanf(path, "%d", &activityID)

	if activityID == 0 {
		http.Error(w, "无效的记录ID", http.StatusBadRequest)
		return
	}

	var userIDInt int
	fmt.Sscanf(userID, "%d", &userIDInt)

	// 验证记录是否属于当前用户
	var ownerID int
	err := database.DB.QueryRow("SELECT user_id FROM health_activities WHERE id = ?", activityID).Scan(&ownerID)
	if err != nil {
		json.NewEncoder(w).Encode(ActivityResponse{
			Success: false,
			Message: "记录不存在",
		})
		return
	}

	if ownerID != userIDInt {
		http.Error(w, "无权删除此记录", http.StatusForbidden)
		return
	}

	// 删除记录
	_, err = database.DB.Exec("DELETE FROM health_activities WHERE id = ?", activityID)
	if err != nil {
		http.Error(w, "删除失败", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(ActivityResponse{
		Success: true,
		Message: "删除成功",
	})
}

// calcLastTwoIntervalDays 计算最后两条记录的间隔天数，tag 为空查全部，auto/manual 按标签过滤，不足2条返回-1
func calcLastTwoIntervalDays(userID int, tagFilter string) int {
	query := "SELECT record_date FROM health_activities WHERE user_id = ?"
	args := []interface{}{userID}
	if tagFilter == "auto" {
		query += " AND tag = 'auto'"
	} else if tagFilter == "manual" {
		query += " AND (COALESCE(tag, 'manual') = 'manual')"
	}
	query += " ORDER BY record_date DESC, record_time DESC LIMIT 2"

	rows, err := database.DB.Query(query, args...)
	if err != nil {
		return -1
	}
	defer rows.Close()

	var dates []string
	for rows.Next() {
		var d string
		if err := rows.Scan(&d); err != nil {
			return -1
		}
		dates = append(dates, d)
	}
	if len(dates) < 2 {
		return -1
	}

	t1, err1 := time.Parse("2006-01-02", dates[0])
	t2, err2 := time.Parse("2006-01-02", dates[1])
	if err1 != nil || err2 != nil {
		return -1
	}
	days := int(t1.Sub(t2).Hours() / 24)
	if days < 0 {
		days = -days
	}
	return days
}

func roundToOneDecimal(v float64) float64 {
	return float64(int(v*10+0.5)) / 10
}

func parseRecordDateTime(date, t string) (time.Time, error) {
	if len(t) == 5 {
		t += ":00"
	}
	return time.ParseInLocation("2006-01-02 15:04:05", date+" "+t, time.Local)
}

func calcRangeDays(userID int, tagFilter string) float64 {
	query := "SELECT record_date, record_time FROM health_activities WHERE user_id = ?"
	args := []interface{}{userID}
	if tagFilter == "auto" {
		query += " AND tag = 'auto'"
	} else if tagFilter == "manual" {
		query += " AND (COALESCE(tag, 'manual') = 'manual')"
	}

	var minDate, minTime string
	if err := database.DB.QueryRow(query+" ORDER BY record_date ASC, record_time ASC LIMIT 1", args...).Scan(&minDate, &minTime); err != nil {
		return 1
	}
	var maxDate, maxTime string
	if err := database.DB.QueryRow(query+" ORDER BY record_date DESC, record_time DESC LIMIT 1", args...).Scan(&maxDate, &maxTime); err != nil {
		return 1
	}
	minDT, err1 := parseRecordDateTime(minDate, minTime)
	maxDT, err2 := parseRecordDateTime(maxDate, maxTime)
	if err1 != nil || err2 != nil {
		return 1
	}
	spanDays := maxDT.Sub(minDT).Hours() / 24.0
	if spanDays <= 0 {
		spanDays = 1
	}
	return spanDays
}

func calcFrequencyPerDayByRange(total int, spanDays float64) float64 {
	if total <= 0 {
		return 0
	}
	if spanDays <= 0 {
		spanDays = 1
	}
	return roundToOneDecimal(float64(total) / spanDays)
}

func calcPeriodDaysByRange(total int, spanDays float64) float64 {
	if total <= 0 {
		return 0
	}
	if spanDays <= 0 {
		spanDays = 1
	}
	return roundToOneDecimal(spanDays / float64(total))
}

// calcLastTwoIntervalDaysFloat 计算最后两条记录的间隔天数（小数），不足2条返回 nil
func calcLastTwoIntervalDaysFloat(userID int, tagFilter string) *float64 {
	query := "SELECT record_date, record_time FROM health_activities WHERE user_id = ?"
	args := []interface{}{userID}
	if tagFilter == "auto" {
		query += " AND tag = 'auto'"
	} else if tagFilter == "manual" {
		query += " AND (COALESCE(tag, 'manual') = 'manual')"
	}
	query += " ORDER BY record_date DESC, record_time DESC LIMIT 2"

	rows, err := database.DB.Query(query, args...)
	if err != nil {
		return nil
	}
	defer rows.Close()

	type pair struct {
		date string
		t    string
	}
	var items []pair
	for rows.Next() {
		var p pair
		if err := rows.Scan(&p.date, &p.t); err != nil {
			return nil
		}
		items = append(items, p)
	}
	if len(items) < 2 {
		return nil
	}
	t1, err1 := parseRecordDateTime(items[0].date, items[0].t)
	t2, err2 := parseRecordDateTime(items[1].date, items[1].t)
	if err1 != nil || err2 != nil {
		return nil
	}
	days := t1.Sub(t2).Hours() / 24.0
	if days < 0 {
		days = -days
	}
	v := roundToOneDecimal(days)
	return &v
}

// calcLastToNowDaysFloat 计算最后一次距今的天数（小数），无记录返回 nil
func calcLastToNowDaysFloat(userID int) *float64 {
	var date, t string
	err := database.DB.QueryRow(
		"SELECT record_date, record_time FROM health_activities WHERE user_id = ? ORDER BY record_date DESC, record_time DESC LIMIT 1",
		userID,
	).Scan(&date, &t)
	if err != nil {
		return nil
	}
	last, err := parseRecordDateTime(date, t)
	if err != nil {
		return nil
	}
	days := time.Since(last).Hours() / 24.0
	if days < 0 {
		return nil
	}
	v := roundToOneDecimal(days)
	return &v
}

// 获取健康活动统计
func getActivityStatsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		return
	}

	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		http.Error(w, "未授权", http.StatusUnauthorized)
		return
	}

	var userIDInt int
	fmt.Sscanf(userID, "%d", &userIDInt)

	now := utils.Now()
	currentYear := now.Format("2006")
	currentMonth := now.Format("2006-01")

	// 查询总计（自动/手动，旧数据 NULL 视为手动）
	var totalAuto, totalManual int
	database.DB.QueryRow(
		"SELECT COUNT(*) FROM health_activities WHERE user_id = ? AND tag = 'auto'",
		userIDInt,
	).Scan(&totalAuto)
	database.DB.QueryRow(
		"SELECT COUNT(*) FROM health_activities WHERE user_id = ? AND (COALESCE(tag, 'manual') = 'manual')",
		userIDInt,
	).Scan(&totalManual)

	// 查询最早记录日期
	var earliestDate string
	database.DB.QueryRow(
		"SELECT MIN(record_date) FROM health_activities WHERE user_id = ?",
		userIDInt,
	).Scan(&earliestDate)

	// 查询今年（自动/手动）
	var yearAuto, yearManual int
	database.DB.QueryRow(
		"SELECT COUNT(*) FROM health_activities WHERE user_id = ? AND record_date LIKE ? AND tag = 'auto'",
		userIDInt, currentYear+"%",
	).Scan(&yearAuto)
	database.DB.QueryRow(
		"SELECT COUNT(*) FROM health_activities WHERE user_id = ? AND record_date LIKE ? AND (COALESCE(tag, 'manual') = 'manual')",
		userIDInt, currentYear+"%",
	).Scan(&yearManual)

	// 查询本月（自动/手动）
	var monthAuto, monthManual int
	database.DB.QueryRow(
		"SELECT COUNT(*) FROM health_activities WHERE user_id = ? AND record_date LIKE ? AND tag = 'auto'",
		userIDInt, currentMonth+"%",
	).Scan(&monthAuto)
	database.DB.QueryRow(
		"SELECT COUNT(*) FROM health_activities WHERE user_id = ? AND record_date LIKE ? AND (COALESCE(tag, 'manual') = 'manual')",
		userIDInt, currentMonth+"%",
	).Scan(&monthManual)

	// 最后两次间隔天数（全部、自动、手动），-1 表示不足2条
	lastTwoInterval := calcLastTwoIntervalDays(userIDInt, "")
	lastTwoAutoInterval := calcLastTwoIntervalDays(userIDInt, "auto")
	lastTwoManualInterval := calcLastTwoIntervalDays(userIDInt, "manual")

	// 精确小数间隔 & 距今
	lastIntervalDays := calcLastTwoIntervalDaysFloat(userIDInt, "")
	lastAutoIntervalDays := calcLastTwoIntervalDaysFloat(userIDInt, "auto")
	lastManualIntervalDays := calcLastTwoIntervalDaysFloat(userIDInt, "manual")
	lastToNowDays := calcLastToNowDaysFloat(userIDInt)

	// 周期/频率统计
	totalRangeDays := calcRangeDays(userIDInt, "")
	autoRangeDays := calcRangeDays(userIDInt, "auto")
	manualRangeDays := calcRangeDays(userIDInt, "manual")
	autoFrequencyPerDay := calcFrequencyPerDayByRange(totalAuto, autoRangeDays)
	manualFrequencyPerDay := calcFrequencyPerDayByRange(totalManual, manualRangeDays)
	totalFrequencyPerDay := calcFrequencyPerDayByRange(totalAuto+totalManual, totalRangeDays)
	autoPeriodDays := calcPeriodDaysByRange(totalAuto, autoRangeDays)
	manualPeriodDays := calcPeriodDaysByRange(totalManual, manualRangeDays)
	totalPeriodDays := calcPeriodDaysByRange(totalAuto+totalManual, totalRangeDays)

	stats := ActivityStats{
		TotalAuto:              totalAuto,
		TotalManual:            totalManual,
		YearAuto:               yearAuto,
		YearManual:             yearManual,
		MonthAuto:              monthAuto,
		MonthManual:            monthManual,
		AutoFrequencyPerDay:    autoFrequencyPerDay,
		ManualFrequencyPerDay:  manualFrequencyPerDay,
		TotalFrequencyPerDay:   totalFrequencyPerDay,
		AutoPeriodDays:         autoPeriodDays,
		ManualPeriodDays:       manualPeriodDays,
		TotalPeriodDays:        totalPeriodDays,
		EarliestDate:           earliestDate,
		LastTwoInterval:        lastTwoInterval,
		LastTwoAutoInterval:    lastTwoAutoInterval,
		LastTwoManualInterval:  lastTwoManualInterval,
		LastIntervalDays:       lastIntervalDays,
		LastAutoIntervalDays:   lastAutoIntervalDays,
		LastManualIntervalDays: lastManualIntervalDays,
		LastToNowDays:          lastToNowDays,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(ActivityResponse{
		Success: true,
		Message: "获取成功",
		Stats:   &stats,
	})
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, Range")
		w.Header().Set("Access-Control-Expose-Headers", "Content-Length, Content-Range, Accept-Ranges")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func main() {
	initDB()
	defer database.CloseDB()

	mux := http.NewServeMux()

	// 公开路由
	mux.HandleFunc("/api/register", registerHandler)
	mux.HandleFunc("/api/login", loginHandler)

	// 需要认证的路由
	mux.HandleFunc("/api/profile", authMiddleware(profileHandler))
	// 注意：更具体的路径要先注册
	mux.HandleFunc("/api/activities/stats", authMiddleware(getActivityStatsHandler))
	mux.HandleFunc("/api/activities/", authMiddleware(deleteActivityHandler))
	mux.HandleFunc("/api/activities", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost {
			authMiddleware(createActivityHandler)(w, r)
		} else if r.Method == http.MethodGet {
			authMiddleware(listActivitiesHandler)(w, r)
		} else {
			http.Error(w, "方法不允许", http.StatusMethodNotAllowed)
		}
	})
	// 抖音解析相关路由
	mux.HandleFunc("/api/douyin/parsing", authMiddleware(handlers.DouyinParsingHandler))
	mux.HandleFunc("/api/douyin/files", authMiddleware(handlers.DouyinFileListHandler))
	mux.HandleFunc("/api/douyin/download", authMiddleware(handlers.DouyinDownloadHandler))

	// 文件传输相关路由
	mux.HandleFunc("/api/file/upload", authMiddleware(handlers.FileUploadHandler))
	mux.HandleFunc("/api/file/list", authMiddleware(handlers.FileListHandler))
	mux.HandleFunc("/api/file/delete", authMiddleware(handlers.FileDeleteHandler))
	mux.HandleFunc("/api/file/download", authMiddleware(handlers.FileDownloadHandler))
	mux.HandleFunc("/api/file/clipboard", authMiddleware(handlers.SaveClipboardHandler))

	// 音乐播放器相关路由
	mux.HandleFunc("/api/music/upload", authMiddleware(handlers.MusicUploadHandler))
	mux.HandleFunc("/api/music/list", authMiddleware(handlers.MusicListHandler))
	mux.HandleFunc("/api/music/delete", authMiddleware(handlers.MusicDeleteHandler))
	// stream 路由不使用 authMiddleware，因为它从 URL 参数获取 token
	mux.HandleFunc("/api/music/stream", handlers.MusicStreamHandler)

	// 音乐分享相关路由
	mux.HandleFunc("/api/music/share/create", authMiddleware(handlers.CreateMusicShareHandler))
	mux.HandleFunc("/api/music/share/list", authMiddleware(handlers.GetUserSharesHandler))
	mux.HandleFunc("/api/music/share/delete", authMiddleware(handlers.DeleteMusicShareHandler))
	// 公开分享路由（无需认证）
	mux.HandleFunc("/api/music/share/detail", handlers.GetSharedMusicHandler)
	mux.HandleFunc("/api/music/share/stream", handlers.StreamSharedMusicHandler)
	// Web 播放页面路由（浏览器直接访问）
	mux.HandleFunc("/share/", handlers.ShareWebPlayerHandler)

	// 歌词相关路由
	mux.HandleFunc("/api/lyrics/upload", authMiddleware(handlers.LyricsUploadHandler))
	mux.HandleFunc("/api/lyrics/search", authMiddleware(handlers.LyricsSearchHandler))
	mux.HandleFunc("/api/lyrics/bind", authMiddleware(handlers.LyricsBindHandler))
	mux.HandleFunc("/api/lyrics/unbind", authMiddleware(handlers.LyricsUnbindHandler)) // 解除绑定
	mux.HandleFunc("/api/lyrics/get", handlers.LyricsGetByMusicIDHandler)              // 公开访问，支持分享页面
	mux.HandleFunc("/api/lyrics/delete", authMiddleware(handlers.LyricsDeleteHandler))

	// AriaNg 静态文件服务（放在最后，避免与 API 路由冲突）
	mux.Handle("/ariang/", http.StripPrefix("/ariang/", ariangHandler()))

	handler := corsMiddleware(mux)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("服务器启动在端口 %s", port)
	log.Fatal(http.ListenAndServe(":"+port, handler))
}
