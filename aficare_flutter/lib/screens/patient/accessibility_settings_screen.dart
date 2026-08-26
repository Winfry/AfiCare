import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';

class AccessibilitySettingsScreen extends StatefulWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  State<AccessibilitySettingsScreen> createState() => _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState extends State<AccessibilitySettingsScreen> {
  bool _largeText = false;
  bool _highContrast = false;
  bool _reduceAnimations = false;
  bool _boldText = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _largeText = prefs.getBool('access_large_text') ?? false;
      _highContrast = prefs.getBool('access_high_contrast') ?? false;
      _reduceAnimations = prefs.getBool('access_reduce_animations') ?? false;
      _boldText = prefs.getBool('access_bold_text') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.canopy)));
    }

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.canopy,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => context.go('/patient'),
            ),
            title: const Text('Accessibility', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Customize how AfiCare looks and works for you. These settings help make the app easier to see and use.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text('Display', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),
                  _toggleCard(
                    'Large Text',
                    'Increase text size throughout the app',
                    Icons.format_size_rounded,
                    _largeText,
                    (v) { setState(() => _largeText = v); _savePreference('access_large_text', v); },
                  ),
                  _toggleCard(
                    'Bold Text',
                    'Make text bolder for better readability',
                    Icons.format_bold_rounded,
                    _boldText,
                    (v) { setState(() => _boldText = v); _savePreference('access_bold_text', v); },
                  ),
                  _toggleCard(
                    'High Contrast',
                    'Increase contrast between text and backgrounds',
                    Icons.contrast_rounded,
                    _highContrast,
                    (v) { setState(() => _highContrast = v); _savePreference('access_high_contrast', v); },
                  ),
                  _toggleCard(
                    'Reduce Animations',
                    'Minimize motion effects',
                    Icons.animation_rounded,
                    _reduceAnimations,
                    (v) { setState(() => _reduceAnimations = v); _savePreference('access_reduce_animations', v); },
                  ),

                  const SizedBox(height: 20),
                  const Text('Preview', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _highContrast ? Colors.black : AppColors.borderSubtle, width: _highContrast ? 2 : 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preview Text',
                          style: TextStyle(
                            fontSize: _largeText ? 22 : 16,
                            fontWeight: _boldText ? FontWeight.w800 : FontWeight.w700,
                            color: _highContrast ? Colors.black : AppColors.canopy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'This is how text will appear with your current accessibility settings. Adjust the toggles above to see changes.',
                          style: TextStyle(
                            fontSize: _largeText ? 16 : 13,
                            fontWeight: _boldText ? FontWeight.w600 : FontWeight.normal,
                            color: _highContrast ? Colors.black87 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.canopy,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Button Preview',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _largeText ? 16 : 14,
                              fontWeight: _boldText ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFF57F17), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Settings are saved locally. Sign in on another device to apply the same settings there.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleCard(String title, String desc, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderSubtle)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (value ? AppColors.canopy : Colors.grey).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: value ? AppColors.canopy : Colors.grey, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.canopy,
          ),
        ],
      ),
    );
  }
}
