import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_preferences_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../services/tts_service.dart';
import '../../theme/patient_tokens.dart';
import 'widgets/patient_ui.dart';

/// Accessibility: the one place for the settings that change how AfiCare
/// looks and reads. Every switch here is a real, saved preference that
/// the app applies on every page (see `_RootAppState.build` in main.dart):
///
/// * Text size     → the app's text scale
/// * Bold text     → MediaQuery.boldText (all text drawn bold)
/// * High contrast → the high-contrast theme and the patient colours (PT)
/// * Reduce motion → MediaQuery.disableAnimations (page slides and the
///   patient pages' small animations stop)
/// * Read aloud    → the speaker button on the home page
///
/// They are saved to her account, so they follow her to any phone.
class AccessibilitySettingsScreen extends StatefulWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  State<AccessibilitySettingsScreen> createState() => _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState extends State<AccessibilitySettingsScreen> {
  /// The text size while the slider is being dragged. It is saved once,
  /// when she lets go, rather than on every step of the drag.
  double? _draggingScale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadIfNeeded());
  }

  Future<void> _loadIfNeeded({bool force = false}) async {
    if (!mounted) return;
    final pp = context.read<PreferencesProvider>();
    final id = context.read<AuthProvider>().currentUser?.id;
    if (id == null) return;
    if (force || pp.prefs == null || pp.prefs!.userId != id) {
      await pp.loadPreferences(id);
    }
  }

  Future<void> _save(UserPreferencesModel next) async {
    final pp = context.read<PreferencesProvider>();
    final ok = await pp.save(next);
    if (!ok && mounted) {
      pToast(context, pp.error ?? "We couldn't save that setting, so it hasn't changed.");
    }
  }

  void _testVoice() {
    final ok = tts.speak('Hello. This is AfiCare. This is how your home page will sound.');
    pToast(
      context,
      !tts.isSupported
          ? "Reading aloud isn't supported on this device."
          : ok
              ? 'Speaking now…'
              : 'This browser has no voice available.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<PreferencesProvider>();
    final prefs = pp.prefs;

    if (prefs == null) return const PLoadingPage();

    final saved = prefs.textScale.clamp(0.85, 1.6).toDouble();
    final scale = _draggingScale ?? saved;
    final highContrast = prefs.effectiveTheme == AppThemePreference.highContrast;
    final enabled = !pp.loadFailed;

    return PSliverPage(
      eyebrow: 'Care that fits you',
      title: 'Accessibility',
      subtitle: 'Make AfiCare easier to read and use. These apply on every page, '
          'and are saved to your account, so they follow you to any phone you sign in on.',
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pp.loadFailed) ...[
                PLoadError(what: 'your settings', onRetry: () => _loadIfNeeded(force: true)),
                const SizedBox(height: 16),
              ],

              // ── Reading ───────────────────────────────────────────
              PCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PCardTitle('Reading'),
                    Row(
                      children: [
                        Expanded(child: Text('Text size', style: PT.rowTitle())),
                        Text('${(scale * 100).round()}%',
                            style: PT.rowTitle().copyWith(color: PT.teal)),
                      ],
                    ),
                    Slider(
                      value: scale,
                      min: 0.85,
                      max: 1.6,
                      divisions: 15,
                      activeColor: PT.teal,
                      inactiveColor: PT.progressTrack,
                      label: '${(scale * 100).round()}%',
                      semanticFormatterCallback: (v) => 'Text size ${(v * 100).round()} percent',
                      onChanged: enabled ? (v) => setState(() => _draggingScale = v) : null,
                      onChangeEnd: (v) async {
                        await _save(prefs.copyWith(textScale: v));
                        if (mounted) setState(() => _draggingScale = null);
                      },
                    ),
                    // A sample at the size being chosen. The saved size
                    // already applies to this whole page, so while dragging
                    // the sample is scaled by the difference.
                    _Scaled(
                      factor: scale / saved,
                      child: const PCallout(
                        title: 'Habari! Your next dose is at 8:00.',
                        body: 'This is how text will look across AfiCare.',
                        tone: PTone.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SettingRow(
                      title: 'Bold text',
                      subtitle: 'Draws all text in a heavier weight.',
                      value: prefs.boldText,
                      enabled: enabled,
                      onChanged: (v) => _save(prefs.copyWith(boldText: v)),
                    ),
                    _SettingRow(
                      title: 'High contrast',
                      subtitle: 'Darker text, and clearer lines and borders.',
                      value: highContrast,
                      enabled: enabled,
                      onChanged: (v) => _save(prefs.copyWith(
                        theme: v ? AppThemePreference.highContrast : AppThemePreference.light,
                      )),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Movement ──────────────────────────────────────────
              PCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PCardTitle('Movement'),
                    _SettingRow(
                      title: 'Reduce motion',
                      subtitle: 'Pages appear without sliding, and switches and cards '
                          'change without animating.',
                      value: prefs.reduceMotion,
                      enabled: enabled,
                      onChanged: (v) => _save(prefs.copyWith(reduceMotion: v)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Listening ─────────────────────────────────────────
              PCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PCardTitle('Listening'),
                    _SettingRow(
                      title: 'Read aloud',
                      subtitle: 'Adds a speaker button to your home page that reads '
                          'your day out loud.',
                      value: prefs.textToSpeech,
                      enabled: enabled,
                      onChanged: (v) => _save(prefs.copyWith(textToSpeech: v)),
                    ),
                    const SizedBox(height: 8),
                    PButton('Test the voice',
                        kind: PButtonKind.alt, dense: true, onPressed: _testVoice),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Your phone's own Bold text and Reduce motion settings are followed too, "
                'even when these are off.',
                style: PT.sub(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

/// A labelled on/off setting. The whole row is one control for screen
/// readers, and tapping anywhere on it switches it.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: enabled ? () => onChanged(!value) : null,
        borderRadius: BorderRadius.circular(PT.rRow),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: PT.rowTitle()),
                    const SizedBox(height: 2),
                    Text(subtitle, style: PT.rowSub()),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: value,
                activeColor: PT.white,
                activeTrackColor: PT.teal,
                inactiveTrackColor: PT.toggleOff,
                onChanged: enabled ? onChanged : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws [child]'s text [factor] times larger than the page's text size.
class _Scaled extends StatelessWidget {
  const _Scaled({required this.factor, required this.child});

  final double factor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final base = media.textScaler.scale(1);
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(base * factor)),
      child: child,
    );
  }
}
