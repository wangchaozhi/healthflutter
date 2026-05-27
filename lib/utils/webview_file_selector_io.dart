import 'package:file_picker/file_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

Future<void> configureAndroidWebViewFileSelector(
  WebViewController controller,
) async {
  final platformController = controller.platform;
  if (platformController is! AndroidWebViewController) {
    return;
  }

  await platformController.setOnShowFileSelector((params) async {
    if (params.mode == FileSelectorMode.save) {
      return <String>[];
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: params.mode == FileSelectorMode.openMultiple,
      withData: false,
      withReadStream: false,
    );

    if (result == null) {
      return <String>[];
    }

    return result.files
        .map((file) => file.path)
        .whereType<String>()
        .map((path) => Uri.file(path).toString())
        .toList();
  });
}
