/// Non-web fallback: text-to-speech is not supported off the web build.
class Tts {
  const Tts();

  bool get isSupported => false;

  bool speak(String text) => false;

  void stop() {}
}
