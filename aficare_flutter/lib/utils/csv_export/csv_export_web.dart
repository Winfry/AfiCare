// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation: triggers a real browser download via a Blob +
/// anchor click -- this is the path actually exercised on the deployed
/// GitHub Pages build.
Future<void> exportCsv(String filename, String csvContent) async {
  final bytes = html.Blob([csvContent], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(bytes);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
