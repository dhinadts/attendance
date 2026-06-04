import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<String> saveCsvFile(String fileName, String csv) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(csv, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: fileName,
      text: 'Attendance CSV export',
      fileNameOverrides: [fileName],
    ),
  );
  return 'Saved and shared: ${file.path}';
}
