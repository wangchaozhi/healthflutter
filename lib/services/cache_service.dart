import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

/// 缓存服务 - 用于缓存音乐文件和歌词
class CacheService {
  // 单例模式
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // 缓存目录
  Directory? _musicCacheDir;
  Directory? _lyricsCacheDir;

  // 歌词内存缓存（快速访问）
  final Map<int, String> _lyricsMemoryCache = {};
  final Map<int, Future<String?>> _musicDownloads = {};

  /// 初始化缓存目录
  Future<void> init() async {
    if (kIsWeb) {
      // Web平台不支持文件缓存，只使用内存缓存
      debugPrint('📦 Web平台：只使用内存缓存');
      return;
    }

    try {
      final cacheDir = await getTemporaryDirectory();
      _musicCacheDir = Directory('${cacheDir.path}/music_cache');
      _lyricsCacheDir = Directory('${cacheDir.path}/lyrics_cache');

      // 创建缓存目录
      if (!await _musicCacheDir!.exists()) {
        await _musicCacheDir!.create(recursive: true);
      }
      if (!await _lyricsCacheDir!.exists()) {
        await _lyricsCacheDir!.create(recursive: true);
      }

      debugPrint('📦 缓存目录初始化成功');
      debugPrint('📦 音乐缓存: ${_musicCacheDir!.path}');
      debugPrint('📦 歌词缓存: ${_lyricsCacheDir!.path}');
    } catch (e) {
      debugPrint('❌ 缓存目录初始化失败: $e');
    }
  }

  // ==================== 音乐文件缓存 ====================

  /// 获取音乐缓存文件路径
  String _getMusicCachePath(int musicId) {
    return '${_musicCacheDir!.path}/music_$musicId.mp3';
  }

  /// 检查音乐是否已缓存
  Future<bool> isMusicCached(int musicId) async {
    if (kIsWeb || _musicCacheDir == null) return false;

    try {
      final file = File(_getMusicCachePath(musicId));
      final exists = await file.exists() && await file.length() > 0;
      if (exists) {
        debugPrint('📦 音乐已缓存: $musicId');
      }
      return exists;
    } catch (e) {
      debugPrint('❌ 检查音乐缓存失败: $e');
      return false;
    }
  }

  /// 获取缓存的音乐文件路径（用于播放）
  Future<String?> getCachedMusicPath(int musicId) async {
    if (kIsWeb || _musicCacheDir == null) return null;

    try {
      if (await isMusicCached(musicId)) {
        final filePath = _getMusicCachePath(musicId);
        // 转换为 file:// URI 格式（Windows 平台需要）
        final uri = Uri.file(filePath).toString();
        return uri;
      }
      return null;
    } catch (e) {
      debugPrint('❌ 获取缓存音乐路径失败: $e');
      return null;
    }
  }

  /// 下载并缓存音乐文件
  Future<String?> cacheMusic(int musicId, String streamUrl) async {
    final existing = _musicDownloads[musicId];
    if (existing != null) return existing;

    final download = _cacheMusic(musicId, streamUrl);
    _musicDownloads[musicId] = download;
    try {
      return await download;
    } finally {
      if (identical(_musicDownloads[musicId], download)) {
        _musicDownloads.remove(musicId);
      }
    }
  }

  Future<String?> _cacheMusic(int musicId, String streamUrl) async {
    if (kIsWeb || _musicCacheDir == null) {
      debugPrint('📦 Web平台不支持音乐缓存，直接使用流URL');
      return streamUrl;
    }

    try {
      // 检查是否已缓存
      if (await isMusicCached(musicId)) {
        debugPrint('📦 音乐已存在缓存，跳过下载: $musicId');
        final filePath = _getMusicCachePath(musicId);
        // 转换为 file:// URI 格式（Windows 平台需要）
        final uri = Uri.file(filePath).toString();
        return uri;
      }

      debugPrint('📦 开始下载音乐到缓存: $musicId');
      final file = File(_getMusicCachePath(musicId));
      final temporaryFile = File('${file.path}.part');
      if (await temporaryFile.exists()) await temporaryFile.delete();
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(streamUrl));
        final response = await client
            .send(request)
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          debugPrint('❌ 下载音乐失败: ${response.statusCode}');
          return streamUrl;
        }
        final sink = temporaryFile.openWrite();
        await response.stream.timeout(const Duration(seconds: 30)).pipe(sink);
        if (await file.exists()) await file.delete();
        await temporaryFile.rename(file.path);
        debugPrint('✅ 音乐缓存成功: $musicId (${await file.length()} bytes)');
        // 转换为 file:// URI 格式（Windows 平台需要）
        final uri = Uri.file(file.path).toString();
        return uri;
      } finally {
        client.close();
        if (await temporaryFile.exists()) await temporaryFile.delete();
      }
    } catch (e) {
      debugPrint('❌ 缓存音乐失败: $e');
      return streamUrl; // 返回原始URL
    }
  }

  /// 删除指定音乐的缓存
  Future<void> deleteMusicCache(int musicId) async {
    if (kIsWeb || _musicCacheDir == null) return;

    try {
      final file = File(_getMusicCachePath(musicId));
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ 删除音乐缓存: $musicId');
      }
    } catch (e) {
      debugPrint('❌ 删除音乐缓存失败: $e');
    }
  }

  // ==================== 歌词缓存 ====================

  /// 获取歌词缓存文件路径
  String _getLyricsCachePath(int musicId) {
    return '${_lyricsCacheDir!.path}/lyrics_$musicId.lrc';
  }

  /// 从内存缓存获取歌词
  String? getLyricsFromMemory(int musicId) {
    return _lyricsMemoryCache[musicId];
  }

  /// 检查歌词是否已缓存（内存或文件）
  Future<bool> isLyricsCached(int musicId) async {
    // 先检查内存缓存
    if (_lyricsMemoryCache.containsKey(musicId)) {
      debugPrint('📦 歌词已在内存缓存: $musicId');
      return true;
    }

    // Web平台只使用内存缓存
    if (kIsWeb || _lyricsCacheDir == null) return false;

    // 检查文件缓存
    try {
      final file = File(_getLyricsCachePath(musicId));
      final exists = await file.exists();
      if (exists) {
        debugPrint('📦 歌词已在文件缓存: $musicId');
      }
      return exists;
    } catch (e) {
      debugPrint('❌ 检查歌词缓存失败: $e');
      return false;
    }
  }

  /// 获取缓存的歌词
  Future<String?> getCachedLyrics(int musicId) async {
    // 先从内存缓存读取
    if (_lyricsMemoryCache.containsKey(musicId)) {
      debugPrint('📦 从内存缓存读取歌词: $musicId');
      return _lyricsMemoryCache[musicId];
    }

    // Web平台只使用内存缓存
    if (kIsWeb || _lyricsCacheDir == null) return null;

    // 从文件缓存读取
    try {
      final file = File(_getLyricsCachePath(musicId));
      if (await file.exists()) {
        final content = await file.readAsString();
        // 同时加载到内存缓存
        _lyricsMemoryCache[musicId] = content;
        debugPrint('📦 从文件缓存读取歌词: $musicId');
        return content;
      }
      return null;
    } catch (e) {
      debugPrint('❌ 读取歌词缓存失败: $e');
      return null;
    }
  }

  /// 缓存歌词
  Future<void> cacheLyrics(int musicId, String lyricsContent) async {
    // 保存到内存缓存
    _lyricsMemoryCache[musicId] = lyricsContent;
    debugPrint('📦 歌词已存入内存缓存: $musicId');

    // Web平台只使用内存缓存
    if (kIsWeb || _lyricsCacheDir == null) return;

    // 保存到文件缓存
    try {
      final file = File(_getLyricsCachePath(musicId));
      await file.writeAsString(lyricsContent);
      debugPrint('📦 歌词已存入文件缓存: $musicId');
    } catch (e) {
      debugPrint('❌ 保存歌词缓存失败: $e');
    }
  }

  /// 删除指定歌词的缓存
  Future<void> deleteLyricsCache(int musicId) async {
    // 从内存缓存删除
    _lyricsMemoryCache.remove(musicId);
    debugPrint('🗑️ 从内存缓存删除歌词: $musicId');

    // Web平台只使用内存缓存
    if (kIsWeb || _lyricsCacheDir == null) return;

    // 从文件缓存删除
    try {
      final file = File(_getLyricsCachePath(musicId));
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ 从文件缓存删除歌词: $musicId');
      }
    } catch (e) {
      debugPrint('❌ 删除歌词缓存失败: $e');
    }
  }

  // ==================== 缓存管理 ====================

  /// 清除所有缓存
  Future<void> clearAllCache() async {
    // 清除内存缓存
    _lyricsMemoryCache.clear();
    debugPrint('🗑️ 清除所有内存缓存');

    // Web平台只使用内存缓存
    if (kIsWeb) return;

    // 清除文件缓存
    try {
      if (_musicCacheDir != null && await _musicCacheDir!.exists()) {
        await _musicCacheDir!.delete(recursive: true);
        await _musicCacheDir!.create();
        debugPrint('🗑️ 清除所有音乐缓存');
      }
      if (_lyricsCacheDir != null && await _lyricsCacheDir!.exists()) {
        await _lyricsCacheDir!.delete(recursive: true);
        await _lyricsCacheDir!.create();
        debugPrint('🗑️ 清除所有歌词缓存');
      }
    } catch (e) {
      debugPrint('❌ 清除缓存失败: $e');
    }
  }

  /// 获取缓存大小（字节）
  Future<int> getCacheSize() async {
    int totalSize = 0;

    // 统计内存缓存（歌词）
    if (_lyricsMemoryCache.isNotEmpty) {
      for (var lyrics in _lyricsMemoryCache.values) {
        // 估算内存中字符串的字节大小（UTF-8编码）
        totalSize += lyrics.length * 2; // 中文字符大约2字节
      }
    }

    // Web平台只统计内存缓存
    if (kIsWeb) {
      return totalSize;
    }

    // 统计文件缓存
    try {
      if (_musicCacheDir != null && await _musicCacheDir!.exists()) {
        final musicFiles = await _musicCacheDir!.list().toList();
        for (var file in musicFiles) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }
      if (_lyricsCacheDir != null && await _lyricsCacheDir!.exists()) {
        final lyricsFiles = await _lyricsCacheDir!.list().toList();
        for (var file in lyricsFiles) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }
    } catch (e) {
      debugPrint('❌ 获取缓存大小失败: $e');
    }
    return totalSize;
  }

  /// 格式化缓存大小
  String formatCacheSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
