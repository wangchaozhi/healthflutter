package handlers

import (
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"backend/utils"
	"github.com/golang-jwt/jwt/v5"
)

func TestMain(m *testing.M) {
	_ = os.Setenv("JWT_SECRET", "test-secret-that-is-at-least-thirty-two-bytes-long")
	os.Exit(m.Run())
}

func TestAuthMiddlewareIgnoresForgedIdentityHeaders(t *testing.T) {
	token, err := GenerateToken("alice", 7)
	if err != nil {
		t.Fatal(err)
	}

	var gotUserID int
	handler := AuthMiddleware(func(w http.ResponseWriter, r *http.Request) {
		gotUserID = GetUserID(r)
		w.WriteHeader(http.StatusNoContent)
	})
	request := httptest.NewRequest(http.MethodGet, "/", nil)
	request.Header.Set("Authorization", "Bearer "+token)
	request.Header.Set("X-User-ID", "999")
	request.Header.Set("X-Username", "mallory")
	response := httptest.NewRecorder()

	handler(response, request)

	if response.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusNoContent)
	}
	if gotUserID != 7 {
		t.Fatalf("user id = %d, want 7", gotUserID)
	}
}

func TestForgedIdentityHeaderWithoutTokenIsRejected(t *testing.T) {
	handler := AuthMiddleware(func(w http.ResponseWriter, r *http.Request) {
		t.Fatal("unauthenticated request reached handler")
	})
	request := httptest.NewRequest(http.MethodGet, "/", nil)
	request.Header.Set("X-User-ID", "7")
	response := httptest.NewRecorder()

	handler(response, request)

	if response.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusUnauthorized)
	}
}

func TestMusicStreamTicketScopeAndExpiry(t *testing.T) {
	ticket, err := GenerateMusicStreamTicket(7, 42)
	if err != nil {
		t.Fatal(err)
	}
	claims, err := VerifyMusicStreamTicket(ticket)
	if err != nil {
		t.Fatal(err)
	}
	if claims.UserID != 7 || claims.MusicID != 42 {
		t.Fatalf("unexpected claims: %+v", claims)
	}
	if _, err := VerifyToken(ticket); err == nil {
		t.Fatal("stream ticket must not be accepted as an access token")
	}

	key, err := loadJWTKey()
	if err != nil {
		t.Fatal(err)
	}
	expired := jwt.NewWithClaims(jwt.SigningMethodHS256, MusicStreamClaims{
		UserID:  7,
		MusicID: 42,
		Purpose: streamTokenPurpose,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(utils.NowUTC().Add(-time.Minute)),
		},
	})
	expiredToken, err := expired.SignedString(key)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := VerifyMusicStreamTicket(expiredToken); err == nil {
		t.Fatal("expired stream ticket was accepted")
	}
}
