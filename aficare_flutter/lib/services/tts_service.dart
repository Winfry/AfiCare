import 'tts_stub.dart' if (dart.library.js_interop) 'tts_web.dart';

/// Platform-selected text-to-speech instance.
///
/// On web this binds to the browser's SpeechSynthesis API. On other
/// platforms [isSupported] is false and [speak] is a no-op.
const Tts tts = Tts();
