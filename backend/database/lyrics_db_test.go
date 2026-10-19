package database

import (
	"database/sql"
	"errors"
	"path/filepath"
	"testing"

	"backend/models"
)

func TestLyricsBindingRequiresMusicAndLyricsOwnership(t *testing.T) {
	if err := InitDB(filepath.Join(t.TempDir(), "lyrics.db")); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = CloseDB() })
	if _, err := DB.Exec(`
		INSERT INTO users (id, username, password) VALUES
		(1, 'alice', 'hash'),
		(2, 'bob', 'hash')
	`); err != nil {
		t.Fatal(err)
	}

	aliceMusic := &models.Music{
		UserID: 1, Title: "alice song", FilePath: "alice.mp3",
		FileSize: 1, FileType: "mp3",
	}
	bobMusic := &models.Music{
		UserID: 2, Title: "bob song", FilePath: "bob.mp3",
		FileSize: 1, FileType: "mp3",
	}
	if err := SaveMusic(aliceMusic); err != nil {
		t.Fatal(err)
	}
	if err := SaveMusic(bobMusic); err != nil {
		t.Fatal(err)
	}
	lyrics := &models.Lyrics{
		UserID: 1, Title: "lyrics", Content: "[00:00.00]test",
		FilePath: "lyrics.lrc",
	}
	if err := SaveLyrics(lyrics); err != nil {
		t.Fatal(err)
	}

	if err := BindLyricsToMusic(lyrics.ID, bobMusic.ID, 1); !errors.Is(err, sql.ErrNoRows) {
		t.Fatalf("cross-user binding error = %v, want sql.ErrNoRows", err)
	}
	if err := BindLyricsToMusic(lyrics.ID, aliceMusic.ID, 1); err != nil {
		t.Fatal(err)
	}
	if err := UnbindLyricsFromMusic(aliceMusic.ID, 2); !errors.Is(err, sql.ErrNoRows) {
		t.Fatalf("cross-user unbind error = %v, want sql.ErrNoRows", err)
	}

	var count int
	if err := DB.QueryRow(
		"SELECT COUNT(*) FROM music_lyrics_binding WHERE music_id = ?",
		aliceMusic.ID,
	).Scan(&count); err != nil {
		t.Fatal(err)
	}
	if count != 1 {
		t.Fatalf("binding count = %d, want 1", count)
	}
}
