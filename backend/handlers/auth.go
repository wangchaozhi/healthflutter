package handlers

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"
	
	"github.com/golang-jwt/jwt/v5"
)

// JWT密钥 - 生产环境请使用环境变量
var JwtKey = []byte("your-secret-key-change-in-production")

// Claims JWT声明
type Claims struct {
	Username string `json:"username"`
	UserID   int    `json:"user_id"`
	jwt.RegisteredClaims
}

// GenerateToken 生成JWT token
func GenerateToken(username string, userID int) (string, error) {
	claims := Claims{
		Username: username,
		UserID:   userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(JwtKey)
}

// VerifyToken 验证JWT token并返回Claims
func VerifyToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		return JwtKey, nil
	})

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}

	return nil, fmt.Errorf("无效的token")
}

// ParseToken 解析JWT token并返回用户ID
func ParseToken(tokenString string) (int, error) {
	claims, err := VerifyToken(tokenString)
	if err != nil {
		return 0, err
	}
	return claims.UserID, nil
}

// GetUserID 从请求头中获取用户ID（由AuthMiddleware设置）
func GetUserID(r *http.Request) int {
	userIDStr := r.Header.Get("X-User-ID")
	if userIDStr == "" {
		return 0
	}
	userID, err := strconv.Atoi(userIDStr)
	if err != nil {
		return 0
	}
	return userID
}

// GetUsername 从请求头中获取用户名（由AuthMiddleware设置）
func GetUsername(r *http.Request) string {
	return r.Header.Get("X-Username")
}

// AuthMiddleware JWT认证中间件
func AuthMiddleware(next http.HandlerFunc) http.HandlerFunc {
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

		claims, err := VerifyToken(parts[1])
		if err != nil {
			http.Error(w, "无效的token", http.StatusUnauthorized)
			return
		}

		// 将claims存储到请求头中
		r.Header.Set("X-User-ID", fmt.Sprintf("%d", claims.UserID))
		r.Header.Set("X-Username", claims.Username)

		next(w, r)
	}
}

