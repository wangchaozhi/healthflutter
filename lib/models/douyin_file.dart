class DouyinFile {
  final int id;
  final int userId;
  final String url;
  final String fileName;
  final int fileSize;
  final String fileSizeStr;
  final String modifiedTime;
  final String path;
  final String createdAt;

  const DouyinFile({
    required this.id,
    required this.userId,
    required this.url,
    required this.fileName,
    required this.fileSize,
    required this.fileSizeStr,
    required this.modifiedTime,
    required this.path,
    required this.createdAt,
  });

  factory DouyinFile.fromJson(Map<String, dynamic> json) {
    return DouyinFile(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      url: json['url'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      fileSizeStr: json['file_size_str'] as String? ?? '',
      modifiedTime: json['modified_time'] as String? ?? '',
      path: json['path'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}
