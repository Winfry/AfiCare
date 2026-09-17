// Saves/shares a generated CSV file. Web and mobile/desktop need
// different mechanisms (browser download vs. a shared temp file), so the
// real implementation is picked at compile time via this conditional
// export -- callers only ever import this file.
export 'csv_export_io.dart' if (dart.library.html) 'csv_export_web.dart';
