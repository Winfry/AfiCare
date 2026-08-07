import 'dart:js_interop';
import 'dart:js_util' as js_util;

/// Web implementation of [Tts] using the browser SpeechSynthesis API
/// (Web Speech API). Called only on web builds via conditional import.
class Tts {
  const Tts();

  JSAny? get _synthesis =>
      js_util.getProperty(js_util.globalThis, 'speechSynthesis');

  bool get isSupported => _synthesis != null;

  bool speak(String text) {
    final synth = _synthesis;
    if (synth == null || text.trim().isEmpty) return false;
    final utterance = js_util.callConstructor(
      js_util.getProperty(js_util.globalThis, 'SpeechSynthesisUtterance'),
      <JSAny?>[text.toJS],
    );
    js_util.callMethod(synth, 'speak', <JSAny?>[utterance]);
    return true;
  }

  void stop() {
    final synth = _synthesis;
    if (synth != null) {
      js_util.callMethod(synth, 'cancel', <JSAny?>[]);
    }
  }
}
