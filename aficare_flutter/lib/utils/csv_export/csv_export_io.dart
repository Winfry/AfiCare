import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile/desktop implementation: writes to a temp file, then opens the
/// native share sheet so the user can save or send it -- there is no
/// direct "download to disk" concept outside a browser.
Future<void> exportCsv(String filename, String csvContent) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(csvContent);
  await Share.shareXFiles([XFile(file.path)]);
}
