import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../providers/consultation_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../models/user_model.dart';
import '../../models/appointment_model.dart';
import '../../models/consultation_model.dart';
import '../../utils/theme.dart';
import 'consultation_screen.dart';
import '../common/notifications_screen.dart';

class ProviderDashboard extends StatefulWidget {
  const ProviderDashboard({super.key});

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isScanning = false;

  // Patient lookup state
  bool _isLoadingPatient = false;
  Map<String, dynamic>? _loadedPatient;
  List<Map<String, dynamic>> _patientConsultations = [];
  String? _patientLookupError;

  // My Patients list (providers who have done consultations)
  List<Map<String, dynamic>> _myPatients = [];
  bool _isLoadingMyPatients = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProviderData());
  }

  void _loadProviderData() {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final aptProvider = Provider.of<AppointmentProvider>(context, listen: false);
    final uid = auth.currentUser?.id;
    if (uid != null) {
      aptProvider.loadProviderAppointments(uid);
      _loadMyPatients(uid);
    }
  }

  Future<void> _loadMyPatients(String providerId) async {
    setState(() => _isLoadingMyPatients = true);
    try {
      final supabase = Supabase.instance.client;
      // Get distinct patients this provider has consulted
      final rows = await supabase
          .from('consultations')
          .select('patient_id, timestamp, chief_complaint, triage_level')
          .eq('provider_id', providerId)
          .order('timestamp', ascending: false);

      // Group by patient_id keeping only the latest consultation
      final Map<String, Map<String, dynamic>> latest = {};
      for (final row in rows as List) {
        final pid = row['patient_id'] as String;
        if (!latest.containsKey(pid)) latest[pid] = Map<String, dynamic>.from(row);
      }

      // Fetch user info for each patient
      final patients = <Map<String, dynamic>>[];
      for (final entry in latest.values) {
        try {
          final user = await supabase
              .from('users')
              .select('id, full_name, medilink_id, phone')
              .eq('id', entry['patient_id'])
              .single();
          patients.add({...user, 'last_complaint': entry['chief_complaint'], 'last_triage': entry['triage_level'], 'last_visit': entry['timestamp']});
        } catch (_) {}
      }

      if (mounted) setState(() { _myPatients = patients; _isLoadingMyPatients = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingMyPatients = false);
    }
  }

  Future<void> _lookupPatient(String medilinkId) async {
    setState(() { _isLoadingPatient = true; _patientLookupError = null; _loadedPatient = null; _patientConsultations = []; });
    try {
      final supabase = Supabase.instance.client;
      // Find patient by MediLink ID
      final userRows = await supabase
          .from('users')
          .select('id, full_name, medilink_id, phone, gender, metadata')
          .eq('medilink_id', medilinkId);

      if ((userRows as List).isEmpty) {
        setState(() { _isLoadingPatient = false; _patientLookupError = 'No patient found with MediLink ID: $medilinkId'; });
        return;
      }

      final patient = Map<String, dynamic>.from(userRows.first);

      // Fetch patient extended profile
      try {
        final profile = await supabase
            .from('patients')
            .select('date_of_birth, gender, blood_type, allergies, chronic_conditions')
            .eq('id', patient['id'])
            .single();
        patient.addAll(profile);
      } catch (_) {}

      // Fetch recent consultations
      final consultRows = await supabase
          .from('consultations')
          .select('id, timestamp, chief_complaint, triage_level, diagnoses, recommendations, vital_signs')
          .eq('patient_id', patient['id'])
          .order('timestamp', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _loadedPatient = patient;
          _patientConsultations = List<Map<String, dynamic>>.from(consultRows as List);
          _isLoadingPatient = false;
        });
        _showPatientRecords(medilinkId, null);
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingPatient = false; _patientLookupError = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ConsultationProvider>(
      builder: (context, authProvider, consultationProvider, child) {
        final user = authProvider.currentUser;
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: _buildAppBar(user),
          body: Column(
            children: [
              _buildProviderHeader(user),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPatientAccessTab(),
                    _buildMyPatientsTab(consultationProvider),
                    _buildNewConsultationTab(),
                    _buildAIAgentDemoTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(UserModel user) {
    return AppBar(
      title: const Text(
        'AfiCare MediLink - Provider',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: AfiCareTheme.primaryBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'Notifications',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsScreen(userRole: 'provider'),
              ),
            );
          },
        ),
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'logout') {
              await Provider.of<AuthProvider>(context, listen: false).signOut();
              if (!mounted) return;
              context.go('/login');
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout),
                  SizedBox(width: 8),
                  Text('Logout'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProviderHeader(UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AfiCareTheme.primaryBlue, Colors.blue[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Text(
              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'D',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AfiCareTheme.primaryBlue,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${user.role.name.toUpperCase()} • Internal Medicine',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AfiCareTheme.primaryBlue,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AfiCareTheme.primaryBlue,
        tabs: const [
          Tab(icon: Icon(Icons.qr_code_scanner), text: 'Access Patient'),
          Tab(icon: Icon(Icons.people), text: 'My Patients'),
          Tab(icon: Icon(Icons.add_circle), text: 'New Consultation'),
          Tab(icon: Icon(Icons.smart_toy), text: 'AI Agent Demo'),
        ],
      ),
    );
  }

  Widget _buildPatientAccessTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Access Patient Records',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildQRScanner(),
          const SizedBox(height: 20),
          _buildAccessCodeInput(),
          const SizedBox(height: 20),
          _buildMedilinkIdSearch(),
        ],
      ),
    );
  }

  Widget _buildQRScanner() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scan Patient QR Code',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_isScanning) ...[
              Container(
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: MobileScanner(
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null) {
                          _handleQRCodeScanned(barcode.rawValue!);
                          break;
                        }
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isScanning = false;
                    });
                  },
                  child: const Text('Stop Scanning'),
                ),
              ),
            ] else ...[
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Tap to start scanning patient QR code',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isScanning = true;
                    });
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Start QR Scanner'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AfiCareTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleQRCodeScanned(String qrData) {
    setState(() => _isScanning = false);
    try {
      // QR may encode a full URL like https://backend/v/ML-NBO-XXXX
      // or a JSON with medilink_id field
      String medilinkId;
      if (qrData.contains('ML-')) {
        // Extract MediLink ID from URL or plain text
        final regex = RegExp(r'ML-[A-Z0-9\-]+');
        final match = regex.firstMatch(qrData);
        medilinkId = match?.group(0) ?? qrData;
      } else {
        final data = jsonDecode(qrData);
        medilinkId = data['medilink_id'] as String? ?? qrData;
      }
      _lookupPatient(medilinkId);
    } catch (e) {
      // Not JSON — try as raw MediLink ID
      _lookupPatient(qrData.trim());
    }
  }

  Widget _buildAccessCodeInput() {
    final accessCodeController = TextEditingController();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Access with Patient Code',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: accessCodeController,
              decoration: const InputDecoration(
                labelText: '6-digit Access Code',
                hintText: '123456',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final code = accessCodeController.text.trim();
                  if (code.isNotEmpty) {
                    // For access codes, show patient records directly
                    _showPatientRecords(code, code);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter an access code'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.lock_open),
                label: const Text('Access with Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AfiCareTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedilinkIdSearch() {
    final medilinkController = TextEditingController();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search by MediLink ID',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: medilinkController,
              decoration: const InputDecoration(
                labelText: 'MediLink ID',
                hintText: 'ML-NBO-XXXX',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (medilinkController.text.isNotEmpty) {
                    _lookupPatient(medilinkController.text.trim().toUpperCase());
                  }
                },
                icon: const Icon(Icons.search),
                label: const Text('Search Patient'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPatientRecords(String medilinkId, String? accessCode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Patient Records',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close patient records',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: _buildPatientRecordsContent(medilinkId),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientRecordsContent(String medilinkId) {
    if (_isLoadingPatient) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_patientLookupError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_patientLookupError!, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
          ],
        ),
      );
    }

    final patient = _loadedPatient;
    if (patient == null) return const SizedBox.shrink();

    final name = patient['full_name'] ?? 'Unknown';
    final mlId = patient['medilink_id'] ?? medilinkId;
    final phone = patient['phone'] ?? 'N/A';
    final dob = patient['date_of_birth'] ?? 'N/A';
    final bloodType = patient['blood_type'] ?? 'Unknown';
    final allergies = (patient['allergies'] as List?)?.join(', ') ?? 'None reported';
    final chronic = (patient['chronic_conditions'] as List?)?.join(', ') ?? 'None';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Patient header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AfiCareTheme.primaryGreen, Color(0xFF1B5E20)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AfiCareTheme.primaryGreen)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(mlId, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                    if (phone != 'N/A') Text(phone, style: const TextStyle(fontSize: 12, color: Colors.white60)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Medical profile
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Medical Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _profileRow('Date of Birth', dob.toString().length >= 10 ? dob.toString().substring(0, 10) : dob.toString()),
                _profileRow('Blood Type', bloodType),
                _profileRow('Chronic Conditions', chronic),
                if (allergies != 'None reported')
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 90, child: Text('Allergies', style: TextStyle(fontSize: 12, color: Colors.grey))),
                      Expanded(child: Text(allergies, style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600))),
                    ],
                  )
                else
                  _profileRow('Allergies', 'None reported'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Consultations
        Text('Recent Consultations (${_patientConsultations.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_patientConsultations.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
            child: const Center(child: Column(children: [
              Icon(Icons.history, size: 40, color: Colors.grey),
              SizedBox(height: 8),
              Text('No consultations recorded yet', style: TextStyle(color: Colors.grey)),
            ])),
          )
        else
          ..._patientConsultations.map((c) {
            final date = c['timestamp']?.toString().substring(0, 10) ?? 'N/A';
            final complaint = c['chief_complaint'] ?? 'N/A';
            final triage = c['triage_level'] ?? 'non_urgent';
            final triageColor = triage == 'emergency' ? Colors.red : triage == 'urgent' ? Colors.orange : Colors.green;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(complaint, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(date, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    )),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: triageColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text(triage.toUpperCase().replaceAll('_', ' '),
                          style: TextStyle(fontSize: 11, color: triageColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 16),

        // Start consultation button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsultationScreen()))
                  .then((_) => _loadProviderData());
            },
            icon: const Icon(Icons.add_circle),
            label: const Text('Start New Consultation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AfiCareTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildVitalSignCard(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyPatientsTab(ConsultationProvider consultationProvider) {
    return _isLoadingMyPatients
        ? const Center(child: CircularProgressIndicator())
        : _myPatients.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No patients yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text(
                        'Patients you have consulted will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _myPatients.length,
                itemBuilder: (ctx, i) {
                  final p = _myPatients[i];
                  final name = p['full_name'] ?? 'Unknown';
                  final mlId = p['medilink_id'] ?? '';
                  final lastVisit = p['last_visit']?.toString().substring(0, 10) ?? '';
                  final triage = p['last_triage'] ?? 'non_urgent';
                  final triageColor = triage == 'emergency'
                      ? Colors.red
                      : triage == 'urgent'
                          ? Colors.orange
                          : Colors.green;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AfiCareTheme.primaryGreen.withOpacity(0.15),
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: AfiCareTheme.primaryGreen, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('$mlId  •  Last visit: $lastVisit',
                          style: const TextStyle(fontSize: 12)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: triageColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(triage.toUpperCase().replaceAll('_', ' '),
                            style: TextStyle(fontSize: 10, color: triageColor, fontWeight: FontWeight.bold)),
                      ),
                      onTap: () => _lookupPatient(mlId),
                    ),
                  );
                },
              );
  }

  Widget _buildNewConsultationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New Patient Consultation',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start New Consultation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ConsultationScreen(),
                          ),
                        ).then((_) => _loadProviderData());
                      },
                      icon: const Icon(Icons.add_circle),
                      label: const Text('Start Consultation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AfiCareTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildTodaysAppointments(),
        ],
      ),
    );
  }

  Widget _buildTodaysAppointments() {
    return Consumer<AppointmentProvider>(
      builder: (ctx, aptProvider, _) {
        final now = DateTime.now();
        final today = aptProvider.appointments.where((a) {
          final d = a.scheduledAt;
          return d.year == now.year &&
              d.month == now.month &&
              d.day == now.day;
        }).toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "Today's Appointments",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (today.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AfiCareTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${today.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (aptProvider.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (today.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Icon(Icons.event_available,
                              size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'No appointments today',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...today.map((a) => _buildProviderAppointmentRow(a)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProviderAppointmentRow(AppointmentModel a) {
    final statusColor = _aptStatusColor(a.status);
    final hour = a.scheduledAt.hour > 12
        ? a.scheduledAt.hour - 12
        : (a.scheduledAt.hour == 0 ? 12 : a.scheduledAt.hour);
    final amPm = a.scheduledAt.hour >= 12 ? 'PM' : 'AM';
    final min = a.scheduledAt.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$min $amPm';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AfiCareTheme.primaryBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              timeStr,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AfiCareTheme.primaryBlue),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.chiefComplaint ?? 'General visit',
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  a.type == AppointmentType.telehealth
                      ? 'Telehealth'
                      : 'In-Person',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _aptStatusLabel(a.status),
              style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Color _aptStatusColor(AppointmentStatus s) {
    switch (s) {
      case AppointmentStatus.pending:
        return Colors.orange;
      case AppointmentStatus.confirmed:
        return Colors.green;
      case AppointmentStatus.completed:
        return Colors.grey;
      case AppointmentStatus.cancelled:
        return Colors.red;
    }
  }

  String _aptStatusLabel(AppointmentStatus s) {
    switch (s) {
      case AppointmentStatus.pending:
        return 'Pending';
      case AppointmentStatus.confirmed:
        return 'Confirmed';
      case AppointmentStatus.completed:
        return 'Done';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
    }
  }

  Widget _buildAIAgentDemoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AfiCare AI Agent - Live Demo',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildAIStatusCard(),
          const SizedBox(height: 20),
          _buildAITestCases(),
        ],
      ),
    );
  }

  Widget _buildAIStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.smart_toy,
                  color: AfiCareTheme.primaryGreen,
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'AfiCare AI Agent Active',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'ONLINE',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAIMetric('Plugins', '3'),
                ),
                Expanded(
                  child: _buildAIMetric('Rule Engine', 'Active'),
                ),
                Expanded(
                  child: _buildAIMetric('Triage Engine', 'Active'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AfiCareTheme.primaryGreen,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildAITestCases() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Test Cases',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _runAITest('malaria'),
                icon: const Icon(Icons.bug_report),
                label: const Text('Test Malaria Case'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _runAITest('pneumonia'),
                icon: const Icon(Icons.air),
                label: const Text('Test Pneumonia Case'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _runAITest('hypertension'),
            icon: const Icon(Icons.favorite),
            label: const Text('Test Hypertension Case'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  void _runAITest(String testCase) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('AI Test: ${testCase.toUpperCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Running AI analysis...'),
            const SizedBox(height: 16),
            Text('Test case: $testCase'),
            const Text('Triage Level: URGENT'),
            const Text('Confidence: 93.2%'),
            const Text('Referral: Yes'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    // Simulate AI processing
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context);
        _showAIResults(testCase);
      }
    });
  }

  void _showAIResults(String testCase) {
    final results = {
      'malaria': {
        'triage': 'URGENT',
        'confidence': '93.2%',
        'conditions': ['Malaria (93.2%)', 'Viral fever (45.1%)', 'Typhoid (32.8%)'],
        'recommendations': [
          'Artemether-Lumefantrine based on weight',
          'Paracetamol for fever and pain',
          'Oral rehydration therapy',
          'Follow-up in 3 days',
        ],
      },
      'pneumonia': {
        'triage': 'EMERGENCY',
        'confidence': '98.8%',
        'conditions': ['Pneumonia (98.8%)', 'Bronchitis (67.3%)', 'Tuberculosis (45.2%)'],
        'recommendations': [
          'Oxygen therapy if SpO2 < 90%',
          'Amoxicillin 500mg three times daily',
          'Adequate fluid intake',
          'Immediate referral to hospital',
        ],
      },
      'hypertension': {
        'triage': 'NON_URGENT',
        'confidence': '87.5%',
        'conditions': ['Hypertension (87.5%)', 'Anxiety (34.2%)', 'Stress (28.7%)'],
        'recommendations': [
          'Lifestyle modifications (diet, exercise)',
          'Regular blood pressure monitoring',
          'Reduce salt intake',
          'Follow-up in 2 weeks',
        ],
      },
    };

    final result = results[testCase]!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('AI Results: ${testCase.toUpperCase()}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🎯 Triage Level: ${result['triage']}'),
              Text('📊 Confidence: ${result['confidence']}'),
              const SizedBox(height: 16),
              const Text(
                '🔍 Suspected Conditions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...(result['conditions'] as List<String>).map(
                (condition) => Text('• $condition'),
              ),
              const SizedBox(height: 16),
              const Text(
                '💊 AI Recommendations:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...(result['recommendations'] as List<String>).map(
                (rec) => Text('• $rec'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}