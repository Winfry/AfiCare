enum AppThemePreference { light, dark, highContrast }

class UserPreferencesModel {
  final String userId;
  final AppThemePreference theme;
  final String language;
  final bool notificationsEnabled;
  final bool emailNotifications;
  final bool smsNotifications;

  /// Accessibility: text size multiplier (1.0 = normal).
  final double textScale;

  /// Accessibility: reduce/disable animations and transitions.
  final bool reduceMotion;

  /// Accessibility: allow text-to-speech for dashboard content.
  final bool textToSpeech;

  UserPreferencesModel({
    required this.userId,
    this.theme = AppThemePreference.light,
    this.language = 'en',
    this.notificationsEnabled = true,
    this.emailNotifications = true,
    this.smsNotifications = false,
    this.textScale = 1.0,
    this.reduceMotion = false,
    this.textToSpeech = false,
  });

  factory UserPreferencesModel.fromJson(Map<String, dynamic> json) {
    return UserPreferencesModel(
      userId: json['user_id'] as String,
      theme: _themeFromString(json['theme'] as String? ?? 'light'),
      language: json['language'] as String? ?? 'en',
      notificationsEnabled: (json['notifications_enabled'] as bool?) ?? true,
      emailNotifications: (json['email_notifications'] as bool?) ?? true,
      smsNotifications: (json['sms_notifications'] as bool?) ?? false,
      textScale: (json['text_scale'] as num?)?.toDouble() ?? 1.0,
      reduceMotion: (json['reduce_motion'] as bool?) ?? false,
      textToSpeech: (json['text_to_speech'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'theme': _themeToString(theme),
      'language': language,
      'notifications_enabled': notificationsEnabled,
      'email_notifications': emailNotifications,
      'sms_notifications': smsNotifications,
      'text_scale': textScale,
      'reduce_motion': reduceMotion,
      'text_to_speech': textToSpeech,
    };
  }

  UserPreferencesModel copyWith({
    AppThemePreference? theme,
    String? language,
    bool? notificationsEnabled,
    bool? emailNotifications,
    bool? smsNotifications,
    double? textScale,
    bool? reduceMotion,
    bool? textToSpeech,
  }) {
    return UserPreferencesModel(
      userId: userId,
      theme: theme ?? this.theme,
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      textScale: textScale ?? this.textScale,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      textToSpeech: textToSpeech ?? this.textToSpeech,
    );
  }

  static AppThemePreference _themeFromString(String s) {
    switch (s) {
      case 'dark':
        return AppThemePreference.dark;
      case 'high_contrast':
        return AppThemePreference.highContrast;
      default:
        return AppThemePreference.light;
    }
  }

  static String _themeToString(AppThemePreference t) {
    switch (t) {
      case AppThemePreference.dark:
        return 'dark';
      case AppThemePreference.highContrast:
        return 'high_contrast';
      case AppThemePreference.light:
        return 'light';
    }
  }
}
