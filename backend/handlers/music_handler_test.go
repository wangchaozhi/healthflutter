package handlers

import (
	"bytes"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"testing"

	"backend/database"
	"backend/models"
)

func TestMusicStreamRejectsInvalidRange(t *testing.T) {
	if err := database.InitDB(filepath.Join(t.TempDir(), "stream.db")); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = database.CloseDB() })
	if _, err := database.DB.Exec(
		"INSERT INTO users (id, username, password) VALUES (7, 'alice', 'hash')",
	); err != nil {
		t.Fatal(err)
	}

	musicPath := filepath.Join(t.TempDir(), "song.mp3")
	if err := os.WriteFile(musicPath, []byte("abcdef"), 0600); err != nil {
		t.Fatal(err)
	}
	music := &models.Music{
		UserID:   7,
		Title:    "song",
		FilePath: musicPath,
		FileSize: 6,
		FileType: "mp3",
	}
	if err := database.SaveMusic(music); err != nil {
		t.Fatal(err)
	}
	ticket, err := GenerateMusicStreamTicket(7, music.ID)
	if err != nil {
		t.Fatal(err)
	}

	request := httptest.NewRequest(
		http.MethodGet,
		"/api/music/stream?id="+strconv.Itoa(music.ID)+"&ticket="+ticket,
		nil,
	)
	request.Header.Set("Range", "bytes=99-100")
	response := httptest.NewRecorder()
	MusicStreamHandler(response, request)

	if response.Code != http.StatusRequestedRangeNotSatisfiable {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusRequestedRangeNotSatisfiable)
	}
}

func TestFileUploadRejectsOversizedBody(t *testing.T) {
	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	part, err := writer.CreateFormFile("file", "large.bin")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := part.Write(bytes.Repeat([]byte{'x'}, maxFileUploadBytes+1)); err != nil {
		t.Fatal(err)
	}
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}

	token, err := GenerateToken("alice", 7)
	if err != nil {
		t.Fatal(err)
	}
	request := httptest.NewRequest(http.MethodPost, "/api/files/upload", &body)
	request.Header.Set("Content-Type", writer.FormDataContentType())
	request.Header.Set("Authorization", "Bearer "+token)
	response := httptest.NewRecorder()

	AuthMiddleware(FileUploadHandler)(response, request)

	if response.Code != http.StatusRequestEntityTooLarge {
		t.Fatalf("status = %d, want %d; body=%s", response.Code, http.StatusRequestEntityTooLarge, response.Body.String())
	}
}
