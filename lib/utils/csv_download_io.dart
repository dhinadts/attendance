import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> saveCsvFile(String fileName, String csv) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(csv, flush: true);
  return file.path;
}
