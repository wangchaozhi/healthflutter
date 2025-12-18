package cn.wangchaozhi.healthflutter

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "cn.wangchaozhi.healthflutter/file_manager"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openDirectory") {
                val path = call.argument<String>("path")
                if (path != null) {
                    openDirectory(path)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGUMENT", "Path is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun openDirectory(path: String) {
        try {
            val directory = File(path)
            if (!directory.exists()) {
                return
            }

            // 优先尝试使用ACTION_GET_CONTENT或ACTION_OPEN_DOCUMENT_TREE打开文件管理器
            // 如果失败，再尝试其他方法
            
            // 方法1: 尝试使用ACTION_OPEN_DOCUMENT_TREE (Android 5.0+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                try {
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    return
                } catch (e: Exception) {
                    // 如果失败，继续尝试其他方法
                }
            }
            
            // 方法2: 尝试使用FileProvider打开目录
            try {
                val intent = Intent(Intent.ACTION_VIEW)
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    val uri = FileProvider.getUriForFile(
                        this,
                        "${applicationContext.packageName}.fileprovider",
                        directory
                    )
                    intent.setDataAndType(uri, "resource/folder")
                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                } else {
                    intent.setDataAndType(Uri.fromFile(directory), "resource/folder")
                }
                
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(Intent.createChooser(intent, "选择文件管理器"))
                return
            } catch (e: Exception) {
                // 如果失败，继续尝试其他方法
            }
            
            // 方法3: 如果是文件，尝试打开文件
            val file = File(path)
            if (file.exists() && file.isFile) {
                openFile(file)
            } else {
                // 方法4: 打开公共下载目录
                openPublicDownloadDirectory()
            }
        } catch (e: Exception) {
            e.printStackTrace()
            // 最后尝试打开公共下载目录
            openPublicDownloadDirectory()
        }
    }

    private fun openFile(file: File) {
        try {
            val intent = Intent(Intent.ACTION_VIEW)
            val mimeType = getMimeType(file.name)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                val uri = FileProvider.getUriForFile(
                    this,
                    "${applicationContext.packageName}.fileprovider",
                    file
                )
                intent.setDataAndType(uri, mimeType)
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } else {
                intent.setDataAndType(Uri.fromFile(file), mimeType)
            }
            
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(Intent.createChooser(intent, "打开文件"))
        } catch (e: Exception) {
            e.printStackTrace()
            openPublicDownloadDirectory()
        }
    }

    private fun openPublicDownloadDirectory() {
        try {
            // 尝试打开公共下载目录
            val downloadDir = File("/storage/emulated/0/Download")
            if (downloadDir.exists()) {
                val intent = Intent(Intent.ACTION_VIEW)
                val uri = Uri.parse("content://com.android.externalstorage.documents/document/primary:Download")
                intent.setDataAndType(uri, "resource/folder")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun getMimeType(fileName: String): String {
        val extension = fileName.substringAfterLast('.', "").lowercase()
        return when (extension) {
            "mp4", "avi", "mov", "mkv", "flv", "wmv", "webm" -> "video/*"
            "jpg", "jpeg", "png", "gif", "bmp" -> "image/*"
            "pdf" -> "application/pdf"
            "txt" -> "text/plain"
            else -> "*/*"
        }
    }
}
