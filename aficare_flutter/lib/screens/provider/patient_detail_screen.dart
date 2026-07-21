import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/prescription_model.dart';
import '../../providers/provider_patient_provider.dart';
import '../../utils/theme.dart';
import 'triage_screen.dart';
import 'referral_screen.dart';
import 'prescription_writer_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;
  const PatientDetailScreen({super.key, required this.patientId});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProviderPatientProvider>(context, listen: false)
          .loadPatientDetail(widget.patientId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProviderPatientProvider>(
      builder: (ctx, provider, _) {
        final patient = provider.patientProfile;

        return Scaffold(
          appBar: AppBar(
            title: Text(patient?['full_name'] ?? 'Patient Detail'),
            backgroundColor: AfiCareTheme.primaryBlue,
            foregroundColor: Colors.white,
            actions: [
              if (patient != null)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'triage':
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => TriageScreen(
                            patientId: widget.patientId,
                            patientName: patient['full_name'] ?? '',
                          ),
                        ));
                        break;
                      case 'refer':
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ReferralScreen(
                            patientId: widget.patientId,
                            patientName: patient['full_name'] ?? '',
                          ),
                        ));
                        break;
                      case 'prescribe':
                        final allergies = (patient['allergies'] as List?)?.cast<String>();
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PrescriptionWriterScreen(
                            patientId: widget.patientId,
                            patientName: patient['full_name'] ?? '',
                            knownAllergies: allergies,
                          ),
                        ));
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'triage', child: ListTile(leading: Icon(Icons.emergency), title: Text('Triage'), dense: true)),
                    const PopupMenuItem(value: 'refer', child: ListTile(leading: Icon(Icons.transfer_within_a_station), title: Text('Refer'), dense: true)),
                    const PopupMenuItem(value: 'prescribe', child: ListTile(leading: Icon(Icons.medication), title: Text('Prescribe'), dense: true)),
                  ],
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: Colors.white,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Vitals'),
                Tab(text: 'Consults'),
                Tab(text: 'Labs'),
                Tab(text: 'Radiology'),
                Tab(text: 'Rx'),
              ],
            ),
          ),
          body: provider.isLoadingPatient
              ? const Center(child: CircularProgressIndicator())
              : patient == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          Text('Patient not found',
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(patient, provider),
                        _buildVitalsTab(provider),
                        _buildConsultsTab(provider),
                        _buildLabsTab(provider),
                        _buildRadiologyTab(provider),
                        _buildRxTab(provider),
                      ],
                    ),
        );
      },
    );
  }

  Widget _buildOverviewTab(Map<String, dynamic> patient, ProviderPatientProvider provider) {
    final name = patient['full_name'] ?? 'Unknown';
    final mlId = patient['medilink_id'] ?? 'N/A';
    final phone = patient['phone'] ?? 'N/A';
    final email = patient['email'] ?? '';
    final dob = patient['date_of_birth']?.toString().substring(0, 10) ?? 'N/A';
    final bloodType = patient['blood_type'] ?? 'N/A';
    final gender = patient['gender'] ?? 'N/A';
    final allergies = (patient['allergies'] as List?)?.join(', ') ?? 'None';
    final chronic = (patient['chronic_conditions'] as List?)?.join(', ') ?? 'None';
    final emergencyContact = patient['emergency_contact'] ?? 'N/A';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AfiCareTheme.primaryBlue, Color(0xFF2D4A7A)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AfiCareTheme.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(mlId, style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8))),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick stats
          Row(
            children: [
              _statCard('Consults', '${provider.consultations.length}', Colors.blue),
              const SizedBox(width: 8),
              _statCard('Active Rx', '${provider.prescriptions.where((p) => p.status.name == 'active').length}', Colors.green),
              const SizedBox(width: 8),
              _statCard('Labs', '${provider.labOrders.length}', Colors.orange),
            ],
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
                  const Divider(),
                  _infoRow('DOB', dob),
                  _infoRow('Gender', gender),
                  _infoRow('Blood Type', bloodType),
                  _infoRow('Phone', phone),
                  if (email.isNotEmpty) _infoRow('Email', email),
                  _infoRow('Emergency Contact', emergencyContact.toString()),
                  const SizedBox(height: 8),
                  if (allergies != 'None')
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Allergies: $allergies',
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500))),
                        ],
                      ),
                    ),
                  if (chronic != 'None') ...[
                    const SizedBox(height: 8),
                    Text('Chronic Conditions: $chronic',
                        style: TextStyle(color: Colors.grey[700])),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsTab(ProviderPatientProvider provider) {
    final assessments = provider.triageAssessments;
    if (assessments.isEmpty) {
      return _emptyState('No vital signs recorded', Icons.monitor_heart_outlined);
    }

    final latest = assessments.first;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Latest Vitals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _vitalCard('Temp', '${latest.temperature?.toStringAsFixed(1) ?? '--'}', '°C')),
              const SizedBox(width: 8),
              Expanded(child: _vitalCard('BP', latest.systolicBP != null ? '${latest.systolicBP}/${latest.diastolicBP ?? '--'}' : '--', 'mmHg')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _vitalCard('HR', '${latest.heartRate ?? '--'}', 'bpm')),
              const SizedBox(width: 8),
              Expanded(child: _vitalCard('RR', '${latest.respiratoryRate ?? '--'}', '/min')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _vitalCard('SpO2', '${latest.oxygenSaturation?.toStringAsFixed(0) ?? '--'}', '%')),
              const SizedBox(width: 8),
              Expanded(child: _vitalCard('Weight', '${latest.weight?.toStringAsFixed(1) ?? '--'}', 'kg')),
            ],
          ),
          const SizedBox(height: 24),
          Text('History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const SizedBox(height: 8),
          ...assessments.take(10).map((a) => Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.chiefComplaint, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(_formatDate(a.assessedAt), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: a.triageColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(a.triageLabel, style: TextStyle(fontSize: 11, color: a.triageColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildConsultsTab(ProviderPatientProvider provider) {
    final consults = provider.consultations;
    if (consults.isEmpty) {
      return _emptyState('No consultations recorded', Icons.history);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: consults.length,
      itemBuilder: (ctx, i) {
        final c = consults[i];
        final triageColor = c.triageLevel == 'emergency' ? Colors.red
            : c.triageLevel == 'urgent' ? Colors.orange : Colors.green;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(c.chiefComplaint, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: triageColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(c.triageLevel.toUpperCase().replaceAll('_', ' '),
                          style: TextStyle(fontSize: 10, color: triageColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_formatDateTime(c.timestamp), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                if (c.diagnoses.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Diagnoses:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                  ...c.diagnoses.map((d) => Text('  • ${d.condition} (${(d.confidence * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
                ],
                if (c.recommendations.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Recommendations:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                  ...c.recommendations.map((r) => Text('  • $r',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabsTab(ProviderPatientProvider provider) {
    final labs = provider.labOrders;
    if (labs.isEmpty) {
      return _emptyState('No lab orders', Icons.science);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: labs.length,
      itemBuilder: (ctx, i) {
        final lab = labs[i];
        final statusColor = lab.isCompleted ? Colors.green : lab.isPending ? Colors.orange : Colors.grey;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(lab.testName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(lab.status.name.toUpperCase(),
                          style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Text(lab.testCategory, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text('Ordered: ${_formatDate(lab.orderedAt)}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                if (lab.result != null) ...[
                  const Divider(),
                  Row(
                    children: [
                      Text('Result: ${lab.result!.resultValue ?? 'N/A'} ${lab.result!.resultUnit ?? ''}',
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                      const SizedBox(width: 8),
                      if (lab.isCritical)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(4)),
                          child: const Text('CRITICAL', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  Text('Ref range: ${lab.result!.referenceRange}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRadiologyTab(ProviderPatientProvider provider) {
    final rads = provider.radiologyOrders;
    if (rads.isEmpty) {
      return _emptyState('No radiology orders', Icons.medical_services);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rads.length,
      itemBuilder: (ctx, i) {
        final r = rads[i];
        final statusColor = r.isReported ? Colors.green : r.isPending ? Colors.orange : Colors.grey;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.medical_services, size: 20, color: AfiCareTheme.primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${r.studyType} — ${r.bodyPart}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(r.status.name.toUpperCase(),
                          style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                if (r.clinicalIndication != null) ...[
                  const SizedBox(height: 4),
                  Text(r.clinicalIndication!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
                if (r.report != null) ...[
                  const Divider(),
                  Text('Findings: ${r.report!.findings ?? 'Pending'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[800])),
                  if (r.report!.impression != null)
                    Text('Impression: ${r.report!.impression}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRxTab(ProviderPatientProvider provider) {
    final rxs = provider.prescriptions;
    if (rxs.isEmpty) {
      return _emptyState('No prescriptions', Icons.medication);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rxs.length,
      itemBuilder: (ctx, i) {
        final rx = rxs[i];
        final statusColor = rx.status == PrescriptionStatus.active
            ? Colors.green : rx.status == PrescriptionStatus.completed
            ? Colors.grey : Colors.red;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(rx.medicationName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(rx.status.name.toUpperCase(),
                          style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${rx.dosage}  •  ${rx.frequency}  •  ${rx.duration}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                if (rx.instructions != null && rx.instructions!.isNotEmpty)
                  Text('Note: ${rx.instructions}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text('Issued: ${_formatDate(rx.issuedAt)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _vitalCard(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AfiCareTheme.primaryBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AfiCareTheme.primaryBlue)),
          Text(unit, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
  String _formatDateTime(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
