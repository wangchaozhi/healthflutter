package services

import (
	"os/exec"
	"strings"
	"testing"
)

func TestExtractURLValidatesDouyinDomain(t *testing.T) {
	got, err := ExtractURL("复制链接 https://v.douyin.com/abc/?foo=1&bar=2 快来看看")
	if err != nil {
		t.Fatal(err)
	}
	if got != "https://v.douyin.com/abc/?foo=1&bar=2" {
		t.Fatalf("url = %q", got)
	}

	for _, input := range []string{
		"https://example.com/video",
		"https://douyin.com.evil.example/video",
		"javascript:alert(1)",
	} {
		if _, err := ExtractURL(input); err == nil {
			t.Fatalf("unsafe URL %q was accepted", input)
		}
	}
}

func TestParsingCommandDoesNotUseShell(t *testing.T) {
	sourceURL := "https://v.douyin.com/video;touch-pwned"
	for _, cmd := range []*exec.Cmd{
		newLinuxParsingCommand(sourceURL),
		newWindowsParsingCommand(sourceURL),
	} {
		if strings.Contains(strings.ToLower(cmd.Path), "bash") ||
			strings.Contains(strings.ToLower(cmd.Path), "cmd.exe") {
			t.Fatalf("command unexpectedly uses a shell: %s", cmd.Path)
		}
		foundExactURL := false
		for _, arg := range cmd.Args {
			if arg == sourceURL {
				foundExactURL = true
			}
		}
		if !foundExactURL {
			t.Fatalf("URL was not passed as one argument: %#v", cmd.Args)
		}
	}
}
