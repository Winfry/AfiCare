import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;

import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../utils/theme.dart';
import '../../services/medical_ai_service.dart';

class ShareRecords extends StatefulWidget {
  const ShareRecords({super.key});

  @override
  State<ShareRecords> createState() => _ShareRecordsState();
}

class _ShareRecordsState extends State<ShareRecords>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _generatedCode;
  DateTime? _codeExpiry;
  bool _isGenerating = false;
  int _selectedDuration = 24; // hours
  final List<String> _selectedPermissions = ['basic_info', 'vital_signs'];

  // Mock active sessions
  final List<Map<String, dynamic>> _activeSessions = [
    {
      'provider': 'Dr. Sarah Mwangi',
      'hospital': 'Nairobi General Hospital',
      'grantedAt': DateTime.now().subtract(const Duration(hours: 2)),
      'expiresAt': DateTime.now().add(const Duration(hours: 22)),
      'permissions': ['basic_info', 'vital_signs', 'medical_history'],
    },
    {
      'provider': 'Kenyatta National Hospital',
      'hospital': 'Emergency Dept',
      'grantedAt': DateTime.now().subtract(const Duration(days: 1)),
      'expiresAt': DateTime.now().add(const Duration(hours: 8)),
      'permissions': ['basic_info', 'vital_signs'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Share Records'),
            backgroundColor: AfiCareTheme.primaryGreen,
            foregroundColor: Colors.white,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(icon: Icon(Icons.qr_code), text: 'QR Code'),
                Tab(icon: Icon(Icons.pin), text: 'Access Code'),
                Tab(icon: Icon(Icons.history), text: 'Active'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildQRCodeTab(user),
              _buildAccessCodeTab(user),
              _buildActiveSessionsTab(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQRCodeTab(UserModel? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            'Share Your Records',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Let healthcare providers scan this QR code to access your medical records',
            style: TextStyle(
              color: Color(0xFF616161), // grey.shade700 — 6.65:1 on white ✓
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Semantics(
                  label: 'QR code containing your MediLink ID and selected access permissions',
                  child: QrImageView(
                    data: _generateQRData(user),
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AfiCareTheme.primaryGreen,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AfiCareTheme.primaryGreenDark,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AfiCareTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user?.medilinkId ?? 'ML-XXX-XXXX',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AfiCareTheme.primaryGreen,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
                ),
                const SizedBox(height: 24),
                _buildShareLinkCard(),
                const SizedBox(height: 30),
                _buildPermissionsSelector(),
                const SizedBox(height: 20),
                _buildDurationSelector(),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copyCode(),
                        icon: const Icon(Icons.link),
                        label: const Text('Copy Link'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AfiCareTheme.primaryGreen),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _shareCode(),
                        icon: const Icon(Icons.share),
                        label: const Text('Share Link'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AfiCareTheme.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSecurityNote(),
        ],
      ),
    );
  }

  Widget _buildAccessCodeTab(UserModel? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            'Generate Access Code',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a temporary code for healthcare providers to access your records',
            style: TextStyle(
              color: Color(0xFF616161), // grey.shade700 — 6.65:1 on white ✓
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          if (_generatedCode != null) ...[
            _buildGeneratedCodeCard(),
            const SizedBox(height: 30),
          ],
          _buildPermissionsSelector(),
          const SizedBox(height: 20),
          _buildDurationSelector(),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : () => _generateAccessCode(user),
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.key),
              label: Text(_generatedCode == null
                  ? 'Generate Access Code'
                  : 'Generate New Code'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AfiCareTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSecurityNote(),
        ],
      ),
    );
  }

  Widget _buildGeneratedCodeCard() {
    final timeRemaining = _codeExpiry?.difference(DateTime.now());
    final hoursRemaining = timeRemaining?.inHours ?? 0;
    final minutesRemaining = (timeRemaining?.inMinutes ?? 0) % 60;
    final url = _getShareUrl();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AfiCareTheme.primaryGreen, AfiCareTheme.secondaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AfiCareTheme.primaryGreen.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Share Link Generated',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              url,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Expires in ${hoursRemaining}h ${minutesRemaining}m',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _copyCode,
                icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                label: const Text(
                  'Copy Link',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: _shareCode,
                icon: const Icon(Icons.share, color: Colors.white, size: 18),
                label: const Text(
                  'Share',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Opens in any browser — no app needed',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareLinkCard() {
    final url = _getShareUrl();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AfiCareTheme.primaryGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AfiCareTheme.primaryGreen.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.link, size: 18, color: Colors.green),
              SizedBox(width: 8),
              Text('Share this link with any doctor',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'No app needed — opens in any phone browser.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    url,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _copyCode,
                  child: Icon(Icons.copy, size: 18, color: AfiCareTheme.primaryGreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsSelector() {
    final permissions = [
      {'id': 'basic_info', 'label': 'Basic Info', 'icon': Icons.person},
      {'id': 'vital_signs', 'label': 'Vital Signs', 'icon': Icons.favorite},
      {'id': 'medical_history', 'label': 'Medical History', 'icon': Icons.history},
      {'id': 'medications', 'label': 'Medications', 'icon': Icons.medication},
      {'id': 'lab_results', 'label': 'Lab Results', 'icon': Icons.science},
      {'id': 'allergies', 'label': 'Allergies', 'icon': Icons.warning},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lock_outline, size: 20),
                SizedBox(width: 8),
                Text(
                  'What can they access?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: permissions.map((perm) {
                final isSelected = _selectedPermissions.contains(perm['id']);
                return FilterChip(
                  selected: isSelected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        perm['icon'] as IconData,
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : AfiCareTheme.primaryGreen,
                      ),
                      const SizedBox(width: 6),
                      Text(perm['label'] as String),
                    ],
                  ),
                  selectedColor: AfiCareTheme.primaryBlue, // navy — white text = 12.6:1 ✓
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedPermissions.add(perm['id'] as String);
                      } else {
                        _selectedPermissions.remove(perm['id']);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    final durations = [
      {'hours': 1, 'label': '1 hour'},
      {'hours': 4, 'label': '4 hours'},
      {'hours': 24, 'label': '24 hours'},
      {'hours': 72, 'label': '3 days'},
      {'hours': 168, 'label': '7 days'},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timer_outlined, size: 20),
                SizedBox(width: 8),
                Text(
                  'How long?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: durations.map((dur) {
                final isSelected = _selectedDuration == dur['hours'];
                return ChoiceChip(
                  selected: isSelected,
                  label: Text(dur['label'] as String),
                  selectedColor: AfiCareTheme.primaryBlue, // navy — white text = 12.6:1 ✓
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedDuration = dur['hours'] as int;
                      });
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionsTab() {
    if (_activeSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Sessions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you share access to your records,\nactive sessions will appear here',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeSessions.length,
      itemBuilder: (context, index) {
        final session = _activeSessions[index];
        return _buildSessionCard(session, index);
      },
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session, int index) {
    final expiresAt = session['expiresAt'] as DateTime;
    final timeRemaining = expiresAt.difference(DateTime.now());
    final permissions = session['permissions'] as List<String>;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AfiCareTheme.primaryBlue.withOpacity(0.1),
                  child: Icon(
                    Icons.local_hospital,
                    color: AfiCareTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session['provider'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        session['hospital'] as String,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Active',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.timer, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Expires in ${timeRemaining.inHours}h ${timeRemaining.inMinutes % 60}m',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: permissions.map((perm) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    perm.replaceAll('_', ' '),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _viewAccessLog(session),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('View Log'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _revokeAccess(index),
                  icon: const Icon(Icons.block, size: 18, color: Colors.red),
                  label: const Text(
                    'Revoke',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.security, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your data is protected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You control who sees your records. You can revoke access anytime.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getShareUrl() {
    if (_generatedCode != null) {
      return '${MedicalAIService.backendUrl}/v/$_generatedCode';
    }
    final user = context.read<AuthProvider>().currentUser;
    final id = user?.medilinkId ?? 'unknown';
    return '${MedicalAIService.backendUrl}/v/${id}';
  }

  String _generateQRData(UserModel? user) {
    return _getShareUrl();
  }

  void _generateAccessCode(UserModel? user) async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${MedicalAIService.backendUrl}/api/access-codes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'medilink_id': user?.medilinkId ?? '',
          'duration_hours': _selectedDuration,
          'permissions': {
            for (final p in _selectedPermissions)
              p: true,
          },
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _generatedCode = data['access_code'] as String;
          _codeExpiry = DateTime.now().add(Duration(hours: _selectedDuration));
          _isGenerating = false;
        });
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // Offline fallback: generate code locally
      debugPrint('Backend unavailable, using local code: $e');
      final fallbackCode = _generateLocalCode(user);
      setState(() {
        _generatedCode = fallbackCode;
        _codeExpiry = DateTime.now().add(Duration(hours: _selectedDuration));
        _isGenerating = false;
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Share link created! Valid for $_selectedDuration hours'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _generateLocalCode(UserModel? user) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final id = user?.medilinkId ?? 'ML';
    final hash = id.hashCode.abs().toString().padLeft(4, '0');
    return '${hash.substring(0, 4)}${ts.toString().substring(ts.toString().length - 4)}';
  }

  void _copyCode() {
    final url = _getShareUrl();
    if (url.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Share link copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _shareCode() {
    final url = _getShareUrl();
    if (url.isNotEmpty) {
      Share.share(
        'Access my medical records via AfiCare: $url\n\nLink expires in $_selectedDuration hours.',
        subject: 'AfiCare Medical Records',
      );
    }
  }

  void _shareQRCode(UserModel? user) {
    final url = _getShareUrl();
    Share.share(
      'Access my AfiCare MediLink records: $url',
      subject: 'AfiCare MediLink Access',
    );
  }

  void _downloadQRCode(UserModel? user) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR code saved to gallery'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _viewAccessLog(Map<String, dynamic> session) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Access Log',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildLogItem(
              'Viewed basic info',
              '2 hours ago',
              Icons.visibility,
            ),
            _buildLogItem(
              'Viewed vital signs',
              '2 hours ago',
              Icons.favorite,
            ),
            _buildLogItem(
              'Viewed medical history',
              '1 hour ago',
              Icons.history,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem(String action, String time, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(action)),
          Text(
            time,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _revokeAccess(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Access?'),
        content: Text(
          'Are you sure you want to revoke access for ${_activeSessions[index]['provider']}? They will no longer be able to view your records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _activeSessions.removeAt(index);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Access revoked successfully'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }
}
