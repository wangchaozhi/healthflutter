package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	_ "modernc.org/sqlite"
	"golang.org/x/crypto/bcrypt"
	"github.com/golang-jwt/jwt/v5"
)

var db *sql.DB
var jwtSecret = []byte("your-secret-key-change-in-production")

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

type Claims struct {
	Username string `json:"username"`
	UserID   int    `json:"user_id"`
	jwt.RegisteredClaims
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
	CreatedAt  string `json:"created_at"`
}

type CreateActivityRequest struct {
	RecordDate string `json:"record_date"`
	RecordTime string `json:"record_time"`
	Duration   int    `json:"duration"`
	Remark     string `json:"remark"`
}

type ActivityResponse struct {
	Success bool             `json:"success"`
	Message string           `json:"message"`
	Data    *HealthActivity  `json:"data,omitempty"`
	List    []HealthActivity `json:"list,omitempty"`
	Stats   *ActivityStats   `json:"stats,omitempty"`
}

type ActivityStats struct {
	TotalCount int `json:"total_count"`  // 总计活动次数
	YearCount  int `json:"year_count"`   // 今年活动次数
	MonthCount int `json:"month_count"`   // 本月活动次数
}

func initDB() {
	var err error
	db, err = sql.Open("sqlite", "./health.db")
	if err != nil {
		log.Fatal("无法打开数据库:", err)
	}

	// 创建用户表
	createUserTableSQL := `
	CREATE TABLE IF NOT EXISTS users (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		username TEXT UNIQUE NOT NULL,
		password TEXT NOT NULL,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);`

	_, err = db.Exec(createUserTableSQL)
	if err != nil {
		log.Fatal("无法创建用户表:", err)
	}

	// 创建健康活动记录表
	createActivityTableSQL := `
	CREATE TABLE IF NOT EXISTS health_activities (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL,
		record_date TEXT NOT NULL,
		record_time TEXT NOT NULL,
		week_day TEXT NOT NULL,
		duration INTEGER NOT NULL,
		remark TEXT,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (user_id) REFERENCES users(id)
	);`

	_, err = db.Exec(createActivityTableSQL)
	if err != nil {
		log.Fatal("无法创建健康活动表:", err)
	}

	log.Println("数据库初始化成功")
}

func hashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	return string(bytes), err
}

func checkPasswordHash(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

func generateToken(username string, userID int) (string, error) {
	claims := Claims{
		Username: username,
		UserID:   userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(jwtSecret)
}

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
	err := db.QueryRow("SELECT id FROM users WHERE username = ?", req.Username).Scan(&existingID)
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
	result, err := db.Exec("INSERT INTO users (username, password) VALUES (?, ?)", req.Username, hashedPassword)
	if err != nil {
		http.Error(w, "注册失败", http.StatusInternalServerError)
		return
	}

	userID, _ := result.LastInsertId()

	// 生成token
	token, err := generateToken(req.Username, int(userID))
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
	err := db.QueryRow("SELECT id, password FROM users WHERE username = ?", req.Username).Scan(&userID, &hashedPassword)
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
	token, err := generateToken(req.Username, userID)
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

func verifyToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		return jwtSecret, nil
	})

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}

	return nil, fmt.Errorf("无效的token")
}

func authMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, "未授权", http.StatusUnauthorized)
			return
		}

		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			http.Error(w, "无效的授权头", http.StatusUnauthorized)
			return
		}

		claims, err := verifyToken(parts[1])
		if err != nil {
			http.Error(w, "无效的token", http.StatusUnauthorized)
			return
		}

		// 将claims存储到请求上下文中（可选）
		r.Header.Set("X-User-ID", fmt.Sprintf("%d", claims.UserID))
		r.Header.Set("X-Username", claims.Username)

		next(w, r)
	}
}

func profileHandler(w http.ResponseWriter, r *http.Request) {
	userID := r.Header.Get("X-User-ID")

	var user User
	err := db.QueryRow("SELECT id, username FROM users WHERE id = ?", userID).Scan(&user.ID, &user.Username)
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

	var userIDInt int
	fmt.Sscanf(userID, "%d", &userIDInt)

	// 插入记录
	result, err := db.Exec(
		"INSERT INTO health_activities (user_id, record_date, record_time, week_day, duration, remark) VALUES (?, ?, ?, ?, ?, ?)",
		userIDInt, req.RecordDate, req.RecordTime, weekDay, req.Duration, req.Remark,
	)
	if err != nil {
		http.Error(w, "创建记录失败", http.StatusInternalServerError)
		return
	}

	activityID, _ := result.LastInsertId()

	activity := HealthActivity{
		ID:         int(activityID),
		UserID:     userIDInt,
		RecordDate: req.RecordDate,
		RecordTime: req.RecordTime,
		WeekDay:    weekDay,
		Duration:   req.Duration,
		Remark:     req.Remark,
		CreatedAt:  time.Now().Format("2006-01-02 15:04:05"),
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

	rows, err := db.Query(
		"SELECT id, user_id, record_date, record_time, week_day, duration, remark, created_at FROM health_activities WHERE user_id = ? ORDER BY record_date DESC, record_time DESC LIMIT 10",
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
		err := rows.Scan(
			&activity.ID,
			&activity.UserID,
			&activity.RecordDate,
			&activity.RecordTime,
			&activity.WeekDay,
			&activity.Duration,
			&activity.Remark,
			&activity.CreatedAt,
		)
		if err != nil {
			continue
		}
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
	err := db.QueryRow("SELECT user_id FROM health_activities WHERE id = ?", activityID).Scan(&ownerID)
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
	_, err = db.Exec("DELETE FROM health_activities WHERE id = ?", activityID)
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

	now := time.Now()
	currentYear := now.Format("2006")
	currentMonth := now.Format("2006-01")

	// 查询总计总数
	var totalCount int
	db.QueryRow(
		"SELECT COUNT(*) FROM health_activities WHERE user_id = ?",
		userIDInt,
	).Scan(&totalCount)

	// 查询今年总数
	var yearCount int
	db.QueryRow(
		"SELECT COUNT(*) FROM health_activities WHERE user_id = ? AND record_date LIKE ?",
		userIDInt, currentYear+"%",
	).Scan(&yearCount)

	// 查询本月总数
	var monthCount int
	db.QueryRow(
		"SELECT COUNT(*) FROM health_activities WHERE user_id = ? AND record_date LIKE ?",
		userIDInt, currentMonth+"%",
	).Scan(&monthCount)

	stats := ActivityStats{
		TotalCount: totalCount,
		YearCount:  yearCount,
		MonthCount: monthCount,
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
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func main() {
	initDB()
	defer db.Close()

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

	handler := corsMiddleware(mux)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("服务器启动在端口 %s", port)
	log.Fatal(http.ListenAndServe(":"+port, handler))
}
