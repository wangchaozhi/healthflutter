package handlers

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"backend/utils"
	"github.com/golang-jwt/jwt/v5"
)

const (
	accessTokenPurpose = "access"
	streamTokenPurpose = "music_stream"
)

type authContextKey struct{}

var (
	jwtKey     []byte
	jwtKeyErr  error
	jwtKeyOnce sync.Once
)

func loadJWTKey() ([]byte, error) {
	jwtKeyOnce.Do(func() {
		if secret := os.Getenv("JWT_SECRET"); secret != "" {
			if len(secret) < 32 {
				jwtKeyErr = fmt.Errorf("JWT_SECRET 长度至少需要 32 字节")
				return
			}
			jwtKey = []byte(secret)
			return
		}

		secretFile := os.Getenv("JWT_SECRET_FILE")
		if secretFile == "" {
			secretFile = ".jwt_secret"
		}
		if data, err := os.ReadFile(secretFile); err == nil {
			secret := strings.TrimSpace(string(data))
			if len(secret) < 32 {
				jwtKeyErr = fmt.Errorf("JWT 密钥文件内容长度不足")
				return
			}
			jwtKey = []byte(secret)
			return
		} else if !os.IsNotExist(err) {
			jwtKeyErr = fmt.Errorf("读取 JWT 密钥失败: %w", err)
			return
		}

		randomBytes := make([]byte, 32)
		if _, err := rand.Read(randomBytes); err != nil {
			jwtKeyErr = fmt.Errorf("生成 JWT 密钥失败: %w", err)
			return
		}
		secret := hex.EncodeToString(randomBytes)
		if dir := filepath.Dir(secretFile); dir != "." {
			if err := os.MkdirAll(dir, 0700); err != nil {
				jwtKeyErr = fmt.Errorf("创建 JWT 密钥目录失败: %w", err)
				return
			}
		}
		file, err := os.OpenFile(secretFile, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
		if err != nil {
			if os.IsExist(err) {
				data, readErr := os.ReadFile(secretFile)
				existingSecret := strings.TrimSpace(string(data))
				if readErr == nil && len(existingSecret) >= 32 {
					jwtKey = []byte(existingSecret)
					return
				}
			}
			jwtKeyErr = fmt.Errorf("保存 JWT 密钥失败: %w", err)
			return
		}
		if _, err := file.WriteString(secret); err != nil {
			_ = file.Close()
			_ = os.Remove(secretFile)
			jwtKeyErr = fmt.Errorf("保存 JWT 密钥失败: %w", err)
			return
		}
		_ = file.Close()
		jwtKey = []byte(secret)
	})
	return jwtKey, jwtKeyErr
}

// Claims JWT声明
type Claims struct {
	Username string `json:"username"`
	UserID   int    `json:"user_id"`
	Purpose  string `json:"purpose"`
	jwt.RegisteredClaims
}

// GenerateToken 生成JWT token
func GenerateToken(username string, userID int) (string, error) {
	claims := Claims{
		Username: username,
		UserID:   userID,
		Purpose:  accessTokenPurpose,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(utils.NowUTC().Add(24 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(utils.NowUTC()),
		},
	}

	key, err := loadJWTKey()
	if err != nil {
		return "", err
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(key)
}

// VerifyToken 验证JWT token并返回Claims
func VerifyToken(tokenString string) (*Claims, error) {
	key, err := loadJWTKey()
	if err != nil {
		return nil, err
	}
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if token.Method != jwt.SigningMethodHS256 {
			return nil, fmt.Errorf("不支持的签名算法")
		}
		return key, nil
	}, jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}))

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid && claims.Purpose == accessTokenPurpose {
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

type MusicStreamClaims struct {
	UserID  int    `json:"user_id"`
	MusicID int    `json:"music_id"`
	Purpose string `json:"purpose"`
	jwt.RegisteredClaims
}

func GenerateMusicStreamTicket(userID, musicID int) (string, error) {
	key, err := loadJWTKey()
	if err != nil {
		return "", err
	}
	now := utils.NowUTC()
	claims := MusicStreamClaims{
		UserID:  userID,
		MusicID: musicID,
		Purpose: streamTokenPurpose,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(now.Add(2 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(now),
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(key)
}

func VerifyMusicStreamTicket(tokenString string) (*MusicStreamClaims, error) {
	key, err := loadJWTKey()
	if err != nil {
		return nil, err
	}
	token, err := jwt.ParseWithClaims(tokenString, &MusicStreamClaims{}, func(token *jwt.Token) (interface{}, error) {
		if token.Method != jwt.SigningMethodHS256 {
			return nil, fmt.Errorf("不支持的签名算法")
		}
		return key, nil
	}, jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}))
	if err != nil {
		return nil, err
	}
	claims, ok := token.Claims.(*MusicStreamClaims)
	if !ok || !token.Valid || claims.Purpose != streamTokenPurpose || claims.UserID <= 0 || claims.MusicID <= 0 {
		return nil, fmt.Errorf("无效的播放凭证")
	}
	return claims, nil
}

// GetUserID 从认证中间件写入的请求上下文获取用户ID。
func GetUserID(r *http.Request) int {
	if claims, ok := r.Context().Value(authContextKey{}).(*Claims); ok {
		return claims.UserID
	}
	return 0
}

// GetUsername 从认证中间件写入的请求上下文获取用户名。
func GetUsername(r *http.Request) string {
	if claims, ok := r.Context().Value(authContextKey{}).(*Claims); ok {
		return claims.Username
	}
	return ""
}

// AuthMiddleware JWT认证中间件
func AuthMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, "未授权", http.StatusUnauthorized)
			return
		}

		parts := strings.Fields(authHeader)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			http.Error(w, "无效的授权头", http.StatusUnauthorized)
			return
		}

		claims, err := VerifyToken(parts[1])
		if err != nil {
			http.Error(w, "无效的token", http.StatusUnauthorized)
			return
		}

		ctx := context.WithValue(r.Context(), authContextKey{}, claims)
		next(w, r.WithContext(ctx))
	}
}
