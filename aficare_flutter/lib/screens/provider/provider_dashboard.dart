import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/appointment_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/consultation_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/greeting_header.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/section_head.dart';
import '../../widgets/timeline_item.dart';
import '../../widgets/appointment_row.dart';
import 'consultation_screen.dart';

class ProviderDashboard extends StatefulWidget {
  const ProviderDashboard({super.key});

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isScanning = false;

  bool _isLoadingPatient = false;
  Map<String, dynamic>? _loadedPatient;

  String? _patientLookupError;

  List<Map<String, dynamic>> _myPatients = [];
  bool _isLoadingMyPatients = false;

  int _consultationsCount = 0;
  int _referralsCount = 0;

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
    final consultProvider = Provider.of<ConsultationProvider>(context, listen: false);
    final uid = auth.currentUser?.id;
    if (uid != null) {
      aptProvider.loadProviderAppointments(uid);
      consultProvider.loadConsultationsForProvider(uid);
      _loadMyPatients(uid);
      _loadCounts(uid);
    }
  }

  Future<void> _loadCounts(String providerId) async {
    try {
      final supabase = Supabase.instance.client;
      final results = await Future.wait([
        supabase.from('consultations').select('id').eq('provider_id', providerId),
        supabase.from('referrals').select('id').eq('from_provider_id', providerId),
      ]);
      if (!mounted) return;
      setState(() {
        _consultationsCount = (results[0] as List).length;
        _referralsCount = (results[1] as List).length;
      });
    } catch (_) {}
  }

  Future<void> _loadMyPatients(String providerId) async {
    setState(() => _isLoadingMyPatients = true);
    try {
      final supabase = Supabase.instance.client;
      final rows = await supabase
          .from('consultations')
          .select('patient_id, timestamp, chief_complaint, triage_level')
          .eq('provider_id', providerId)
          .order('timestamp', ascending: false);

      final Map<String, Map<String, dynamic>> latest = {};
      for (final row in rows as List) {
        final pid = row['patient_id'] as String;
        if (!latest.containsKey(pid)) latest[pid] = Map<String, dynamic>.from(row);
      }

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
    setState(() { _isLoadingPatient = true; _patientLookupError = null; _loadedPatient = null; });
    try {
      final supabase = Supabase.instance.client;
      final userRows = await supabase
          .from('users')
          .select('id, full_name, medilink_id, phone, gender, metadata')
          .eq('medilink_id', medilinkId);

      if ((userRows as List).isEmpty) {
        setState(() { _isLoadingPatient = false; _patientLookupError = 'No patient found with MediLink ID: $medilinkId'; });
        return;
      }

      final patient = Map<String, dynamic>.from(userRows.first);

      try {
        final profile = await supabase
            .from('patients')
            .select('date_of_birth, gender, blood_type, allergies, chronic_conditions')
            .eq('id', patient['id'])
            .single();
        patient.addAll(profile);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _loadedPatient = patient;

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
        final isDemo = user == null;
        final name = isDemo ? 'Doctor' : user.fullName.split(' ').last;
        final dept = isDemo ? 'Internal Medicine' : (user.metadata?['department'] as String? ?? 'Internal Medicine');
        final facility = isDemo ? 'AfiCare Demo' : (user.facilityId ?? 'AfiCare');

        final appointments = Provider.of<AppointmentProvider>(context).appointments;
        final now = DateTime.now();
        final todayAppts = appointments
            .where((a) =>
                a.scheduledAt.year == now.year &&
                a.scheduledAt.month == now.month &&
                a.scheduledAt.day == now.day &&
                a.status != AppointmentStatus.cancelled &&
                a.status != AppointmentStatus.completed)
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              GreetingHeader(
                name: name,
                subtitle: '$facility \u00B7 $dept',
              ),

              const SizedBox(height: 24),

              // Stat cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossCount = constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 500 ? 2 : 2);
                  return GridView.count(
                    crossAxisCount: crossCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 2.0,
                    children: [
                      StatCard(
                        label: 'Patients under care',
                        value: _myPatients.length.toString(),
                        icon: Icons.people_outline,
                        hero: true,
                      ),
                      StatCard(
                        label: 'Consultations',
                        value: _consultationsCount.toString(),
                        icon: Icons.assignment_outlined,
                        iconColor: AfiCareTheme.canopy2,
                      ),
                      StatCard(
                        label: 'Referrals',
                        value: _referralsCount.toString(),
                        icon: Icons.reorder_outlined,
                        iconColor: AfiCareTheme.marigold,
                      ),
                      StatCard(
                        label: 'Appointments today',
                        value: todayAppts.length.toString(),
                        icon: Icons.calendar_today_outlined,
                        iconColor: AfiCareTheme.sage,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 32),

              // Two column layout
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 900) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 58, child: _buildActivityTimeline(consultationProvider)),
                        const SizedBox(width: 22),
                        Expanded(flex: 42, child: _buildUpcomingAppointments(todayAppts)),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _buildActivityTimeline(consultationProvider),
                      const SizedBox(height: 22),
                      _buildUpcomingAppointments(todayAppts),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Tabs for deeper features
              _buildTabSection(consultationProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityTimeline(ConsultationProvider consultationProvider) {
    final consultations = consultationProvider.consultations.take(4).toList();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AfiCareTheme.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AfiCareTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHead(title: 'Recent activity'),
          const SizedBox(height: 12),
          if (consultations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No recent consultations', style: TextStyle(color: AfiCareTheme.slate)),
              ),
            )
          else
            ...consultations.indexed.map((entry) {
              final (i, c) = entry;
              return TimelineItem(
                title: 'Consultation recorded',
                subtitle: c.chiefComplaint.isNotEmpty ? c.chiefComplaint : 'Patient visit',
                time: _relativeTime(c.timestamp),
                dotColor: AfiCareTheme.canopy,
                isFirst: i == 0,
                isLast: i == consultations.length - 1,
              );
            }),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildUpcomingAppointments(List todayAppts) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AfiCareTheme.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AfiCareTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHead(title: 'Upcoming appointments'),
          const SizedBox(height: 8),
          if (todayAppts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No appointments today', style: TextStyle(color: AfiCareTheme.slate)),
              ),
            )
          else
            for (final (i, a) in todayAppts.indexed) ...[
              if (i > 0) const Divider(height: 1),
              AppointmentRow(
                time: '${a.scheduledAt.hour.toString().padLeft(2, '0')}:${a.scheduledAt.minute.toString().padLeft(2, '0')}',
                patientName: a.chiefComplaint?.isNotEmpty == true ? a.chiefComplaint! : 'Appointment',
                type: a.type == AppointmentType.telehealth ? 'Telehealth' : 'In-person',
                room: a.status == AppointmentStatus.pending ? 'Pending' : 'Confirmed',
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildTabSection(ConsultationProvider consultationProvider) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AfiCareTheme.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AfiCareTheme.line),
          ),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: AfiCareTheme.canopy,
                unselectedLabelColor: AfiCareTheme.slate,
                indicatorColor: AfiCareTheme.canopy,
                labelStyle: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Patient Access'),
                  Tab(text: 'My Patients'),
                  Tab(text: 'New Consultation'),
                  Tab(text: 'AI Agent'),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 500,
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
    );
  }

  Widget _buildPatientAccessTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQRScanner(),
          const SizedBox(height: 16),
          _buildMedilinkIdSearch(),
        ],
      ),
    );
  }

  Widget _buildQRScanner() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AfiCareTheme.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AfiCareTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Scan Patient QR Code', style: GoogleFonts.fraunces(fontSize: 19, fontWeight: FontWeight.w600, color: AfiCareTheme.ink)),
          const SizedBox(height: 16),
          if (_isScanning) ...[
            Container(
              height: 300,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AfiCareTheme.line)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: MobileScanner(
                  onDetect: (capture) {
                    for (final barcode in capture.barcodes) {
                      if (barcode.rawValue != null) { _handleQRCodeScanned(barcode.rawValue!); break; }
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => setState(() => _isScanning = false),
                child: const Text('Stop Scanning'),
              ),
            ),
          ] else ...[
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AfiCareTheme.mist,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AfiCareTheme.line),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, size: 48, color: AfiCareTheme.slate),
                  const SizedBox(height: 12),
                  Text('Tap to start scanning', style: GoogleFonts.ibmPlexSans(color: AfiCareTheme.slate)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _isScanning = true),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Start QR Scanner'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleQRCodeScanned(String qrData) {
    setState(() => _isScanning = false);
    try {
      String medilinkId;
      if (qrData.contains('ML-')) {
        final regex = RegExp(r'ML-[A-Z0-9\-]+');
        final match = regex.firstMatch(qrData);
        medilinkId = match?.group(0) ?? qrData;
      } else {
        final data = jsonDecode(qrData);
        medilinkId = data['medilink_id'] as String? ?? qrData;
      }
      _lookupPatient(medilinkId);
    } catch (e) {
      _lookupPatient(qrData.trim());
    }
  }

  Widget _buildMedilinkIdSearch() {
    final medilinkController = TextEditingController();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AfiCareTheme.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AfiCareTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Search by MediLink ID', style: GoogleFonts.fraunces(fontSize: 19, fontWeight: FontWeight.w600, color: AfiCareTheme.ink)),
          const SizedBox(height: 16),
          TextField(
            controller: medilinkController,
            style: GoogleFonts.ibmPlexMono(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'ML-NBO-XXXX',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward, size: 18),
                onPressed: () {
                  if (medilinkController.text.isNotEmpty) {
                    _lookupPatient(medilinkController.text.trim().toUpperCase());
                  }
                },
              ),
            ),
          ),
        ],
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
                  const Expanded(child: Text('Patient Records', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(child: SingleChildScrollView(controller: scrollController, child: _buildPatientRecordsContent(medilinkId))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientRecordsContent(String medilinkId) {
    if (_isLoadingPatient) return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
    if (_patientLookupError != null) return Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(_patientLookupError!, style: const TextStyle(color: AfiCareTheme.clay))));
    final patient = _loadedPatient;
    if (patient == null) return const SizedBox.shrink();

    final name = patient['full_name'] ?? 'Unknown';
    final mlId = patient['medilink_id'] ?? medilinkId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AfiCareTheme.canopy, AfiCareTheme.canopy2]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(radius: 28, backgroundColor: Colors.white.withOpacity( 0.2), child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                Text(mlId, style: GoogleFonts.ibmPlexMono(fontSize: 13, color: Colors.white.withOpacity( 0.8))),
              ])),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsultationScreen())).then((_) => _loadProviderData()); },
            icon: const Icon(Icons.add_circle),
            label: const Text('Start New Consultation'),
          ),
        ),
      ],
    );
  }

  Widget _buildMyPatientsTab(ConsultationProvider consultationProvider) {
    if (_isLoadingMyPatients) return const Center(child: CircularProgressIndicator());
    if (_myPatients.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.people_outline, size: 48, color: AfiCareTheme.slate),
      const SizedBox(height: 12),
      Text('No patients yet', style: GoogleFonts.ibmPlexSans(fontSize: 16, color: AfiCareTheme.slate)),
    ]));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myPatients.length,
      itemBuilder: (ctx, i) {
        final p = _myPatients[i];
        final name = p['full_name'] ?? 'Unknown';
        final mlId = p['medilink_id'] ?? '';
        return Card(child: ListTile(
          leading: CircleAvatar(backgroundColor: AfiCareTheme.canopy.withOpacity( 0.1), child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: GoogleFonts.ibmPlexSans(color: AfiCareTheme.canopy, fontWeight: FontWeight.w600))),
          title: Text(name, style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600)),
          subtitle: Text(mlId, style: GoogleFonts.ibmPlexMono(fontSize: 12, color: AfiCareTheme.slate)),
          onTap: () => _lookupPatient(mlId),
        ));
      },
    );
  }

  Widget _buildNewConsultationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New Patient Consultation', style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w700, color: AfiCareTheme.ink)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsultationScreen())).then((_) => _loadProviderData()),
              icon: const Icon(Icons.add_circle),
              label: const Text('Start Consultation'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAgentDemoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AfiCare AI Agent', style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w700, color: AfiCareTheme.ink)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AfiCareTheme.canopy,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withOpacity( 0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.smart_toy, color: Colors.white)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('AI Agent Active', style: GoogleFonts.ibmPlexSans(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  Text('3 plugins · Rule engine active', style: GoogleFonts.ibmPlexSans(fontSize: 12, color: Colors.white.withOpacity( 0.7))),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: AfiCareTheme.sage.withOpacity( 0.3), borderRadius: BorderRadius.circular(999)), child: Text('ONLINE', style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white))),
              ],
            ),
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
