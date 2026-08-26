import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  // Blood type options
  final _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  // Controllers
  final _contactNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _contactRelCtrl = TextEditingController();
  final _contact2NameCtrl = TextEditingController();
  final _contact2PhoneCtrl = TextEditingController();
  final _contact2RelCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _selectedBloodType;
  List<String> _allergies = [];
  final _allergyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final patientId = _supabase.auth.currentUser?.id;
      if (patientId == null) return;

      final data = await _supabase
          .from('emergency_profiles')
          .select()
          .eq('patient_id', patientId)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _profile = data;
          _selectedBloodType = data['blood_type'] as String?;
          _allergies = (data['allergies'] as List?)?.cast<String>() ?? [];
          _contactNameCtrl.text = data['emergency_contact_name'] as String? ?? '';
          _contactPhoneCtrl.text = data['emergency_contact_phone'] as String? ?? '';
          _contactRelCtrl.text = data['emergency_contact_relationship'] as String? ?? '';
          _contact2NameCtrl.text = data['emergency_contact2_name'] as String? ?? '';
          _contact2PhoneCtrl.text = data['emergency_contact2_phone'] as String? ?? '';
          _contact2RelCtrl.text = data['emergency_contact2_relationship'] as String? ?? '';
          _notesCtrl.text = data['notes'] as String? ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading emergency profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final patientId = _supabase.auth.currentUser?.id;
    if (patientId == null) return;

    try {
      final profileData = {
        'patient_id': patientId,
        'blood_type': _selectedBloodType,
        'allergies': _allergies,
        'emergency_contact_name': _contactNameCtrl.text.trim(),
        'emergency_contact_phone': _contactPhoneCtrl.text.trim(),
        'emergency_contact_relationship': _contactRelCtrl.text.trim(),
        'emergency_contact2_name': _contact2NameCtrl.text.trim().isNotEmpty ? _contact2NameCtrl.text.trim() : null,
        'emergency_contact2_phone': _contact2PhoneCtrl.text.trim().isNotEmpty ? _contact2PhoneCtrl.text.trim() : null,
        'emergency_contact2_relationship': _contact2RelCtrl.text.trim().isNotEmpty ? _contact2RelCtrl.text.trim() : null,
        'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      };

      if (_profile != null) {
        profileData['id'] = _profile!['id'] as String;
      }

      await _supabase.from('emergency_profiles').upsert(profileData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency profile saved'), backgroundColor: Color(0xFF2E7D32)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSOSDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.warning_rounded, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 12),
            const Text('Emergency SOS', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Emergency Information:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (_selectedBloodType != null) ...[
              _infoRow('Blood Type', _selectedBloodType!),
              const SizedBox(height: 8),
            ],
            if (_allergies.isNotEmpty) ...[
              _infoRow('Allergies', _allergies.join(', ')),
              const SizedBox(height: 8),
            ],
            if (_contactNameCtrl.text.isNotEmpty)
              _infoRow('Emergency Contact', '${_contactNameCtrl.text} (${_contactPhoneCtrl.text})'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone, color: Colors.red.shade600, size: 20),
                  const SizedBox(width: 8),
                  const Text('Call 999 or 112', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: url_launcher for tel:999
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Call Emergency', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.canopy)),
      );
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
            title: const Text('Emergency Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            actions: [
              // SOS Button
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ElevatedButton.icon(
                  onPressed: _showSOSDialog,
                  icon: const Icon(Icons.warning_rounded, size: 18),
                  label: const Text('SOS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Blood Type Card
                  _buildBloodTypeCard(),
                  const SizedBox(height: 16),

                  // Allergies Card
                  _buildAllergiesCard(),
                  const SizedBox(height: 16),

                  // Emergency Contacts Card
                  _buildContactsCard(),
                  const SizedBox(height: 16),

                  // Notes Card
                  _buildNotesCard(),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.canopy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Emergency Profile', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodTypeCard() {
    return _card(
      title: 'Blood Type',
      icon: Icons.bloodtype_rounded,
      iconColor: Colors.red,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _bloodTypes.map((bt) {
          final selected = _selectedBloodType == bt;
          return GestureDetector(
            onTap: () => setState(() => _selectedBloodType = bt),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? Colors.red.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? Colors.red.shade400 : AppColors.borderSubtle,
                  width: selected ? 2 : 1,
                ),
                boxShadow: selected
                    ? [BoxShadow(color: Colors.red.shade100, blurRadius: 4, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Text(
                bt,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.red.shade700 : AppColors.textPrimary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAllergiesCard() {
    return _card(
      title: 'Allergies',
      icon: Icons.coronavirus_rounded,
      iconColor: Colors.orange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allergies.map((a) => Chip(
              label: Text(a),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => setState(() => _allergies.remove(a)),
              backgroundColor: Colors.orange.shade50,
              side: BorderSide(color: Colors.orange.shade200),
            )).toList(),
          ),
          if (_allergies.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'No allergies recorded. Add critical allergies for emergency responders.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _allergyCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add allergy...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) {
                      setState(() {
                        _allergies.add(v.trim());
                        _allergyCtrl.clear();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  if (_allergyCtrl.text.trim().isNotEmpty) {
                    setState(() {
                      _allergies.add(_allergyCtrl.text.trim());
                      _allergyCtrl.clear();
                    });
                  }
                },
                icon: Icon(Icons.add_circle_rounded, color: Colors.orange.shade600, size: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactsCard() {
    return _card(
      title: 'Emergency Contacts',
      icon: Icons.contact_phone_rounded,
      iconColor: AppColors.canopy,
      child: Column(
        children: [
          _contactField('Contact 1 Name', _contactNameCtrl, Icons.person),
          const SizedBox(height: 8),
          _contactField('Phone', _contactPhoneCtrl, Icons.phone, keyboardType: TextInputType.phone),
          const SizedBox(height: 8),
          _contactField('Relationship', _contactRelCtrl, Icons.group),
          const Divider(height: 24),
          _contactField('Contact 2 Name (optional)', _contact2NameCtrl, Icons.person_outline),
          const SizedBox(height: 8),
          _contactField('Phone (optional)', _contact2PhoneCtrl, Icons.phone_outlined, keyboardType: TextInputType.phone),
          const SizedBox(height: 8),
          _contactField('Relationship (optional)', _contact2RelCtrl, Icons.group_outlined),
        ],
      ),
    );
  }

  Widget _contactField(String label, TextEditingController ctrl, IconData icon,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500),
        prefixIcon: Icon(icon, color: AppColors.canopy, size: 20),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.canopy, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return _card(
      title: 'Additional Notes',
      icon: Icons.notes_rounded,
      iconColor: Colors.teal,
      child: TextField(
        controller: _notesCtrl,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Medical conditions, religious preferences for treatment, etc.',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.canopy, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  @override
  void dispose() {
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _contactRelCtrl.dispose();
    _contact2NameCtrl.dispose();
    _contact2PhoneCtrl.dispose();
    _contact2RelCtrl.dispose();
    _notesCtrl.dispose();
    _allergyCtrl.dispose();
    super.dispose();
  }
}
