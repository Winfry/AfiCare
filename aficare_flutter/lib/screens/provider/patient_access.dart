import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../utils/theme.dart';

class PatientAccess extends StatefulWidget {
  const PatientAccess({super.key});

  @override
  State<PatientAccess> createState() => _PatientAccessState();
}

class _PatientAccessState extends State<PatientAccess>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _accessCodeController = TextEditingController();
  final _medilinkIdController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _patientData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _accessCodeController.dispose();
    _medilinkIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Patient Records'),
        backgroundColor: AfiCareTheme.primaryBlue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
            Tab(icon: Icon(Icons.pin), text: 'Access Code'),
            Tab(icon: Icon(Icons.search), text: 'MediLink ID'),
          ],
        ),
      ),
      body: _patientData != null
          ? _buildPatientRecordView()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildQRScannerTab(),
                _buildAccessCodeTab(),
                _buildMedilinkSearchTab(),
              ],
            ),
    );
  }

  Widget _buildQRScannerTab() {
    return Stack(
      children: [
        MobileScanner(
          onDetect: _onQRDetect,
        ),
        Container(
          decoration: const ShapeDecoration(
            shape: _ScannerOverlay(
              borderColor: Colors.white,
              borderRadius: 16,
              borderLength: 30,
              borderWidth: 8,
              cutOutSize: 280,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.qr_code_scanner,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Scan Patient QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ask the patient to show their AfiCare MediLink QR code',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccessCodeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AfiCareTheme.primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pin,
                size: 60,
                color: AfiCareTheme.primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Enter Access Code',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Ask the patient for their temporary access code',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _accessCodeController,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              hintText: '------',
              hintStyle: TextStyle(
                fontSize: 32,
                letterSpacing: 8,
                color: Colors.grey.shade300,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AfiCareTheme.primaryBlue,
                  width: 2,
                ),
              ),
            ),
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              UpperCaseTextFormatter(),
            ],
            onChanged: (value) {
              if (value.length == 6) {
                _verifyAccessCode(value);
              }
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _verifyAccessCode(_accessCodeController.text),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AfiCareTheme.primaryBlue,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Verify Code'),
            ),
          ),
          const SizedBox(height: 32),
          _buildSecurityInfo(),
        ],
      ),
    );
  }

  Widget _buildMedilinkSearchTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AfiCareTheme.primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.badge,
                size: 60,
                color: AfiCareTheme.primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Search by MediLink ID',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Enter the patient\'s unique MediLink identifier',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _medilinkIdController,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: 'MediLink ID',
              hintText: 'ML-NBO-123456',
              prefixIcon: const Icon(Icons.badge),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AfiCareTheme.primaryBlue,
                  width: 2,
                ),
              ),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _searchMedilinkId(_medilinkIdController.text),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search),
              label: const Text('Search Patient'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AfiCareTheme.primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildSecurityInfo(),
          const SizedBox(height: 24),
          _buildRecentSearches(),
        ],
      ),
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.security, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patient Consent Required',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Patient must explicitly grant access. All access is logged and audited.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches() {
    final recentSearches = [
      {'id': 'ML-NBO-847291', 'name': 'Jane Wanjiku', 'time': '2 hours ago'},
      {'id': 'ML-NBO-639472', 'name': 'Peter Omondi', 'time': 'Yesterday'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Patients',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...recentSearches.map((search) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AfiCareTheme.primaryGreen.withOpacity(0.1),
              child: Text(
                search['name']!.substring(0, 1),
                style: TextStyle(
                  color: AfiCareTheme.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(search['name']!),
            subtitle: Text(search['id']!),
            trailing: Text(
              search['time']!,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
            onTap: () {
              _medilinkIdController.text = search['id']!;
              _searchMedilinkId(search['id']!);
            },
          ),
        )),
      ],
    );
  }

  Widget _buildPatientRecordView() {
    final patient = _patientData!;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Patient header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AfiCareTheme.primaryBlue, Colors.blue.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: Text(
                    patient['name'].substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: AfiCareTheme.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  patient['name'],
                  style: const TextStyle(
                    fontSize: 24,
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
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    patient['medilinkId'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPatientInfoChip(
                      Icons.cake,
                      '${patient['age']} years',
                    ),
                    const SizedBox(width: 16),
                    _buildPatientInfoChip(
                      patient['gender'] == 'Female' ? Icons.female : Icons.male,
                      patient['gender'],
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Critical alerts
                if (patient['alerts'] != null && (patient['alerts'] as List).isNotEmpty)
                  _buildAlertsCard(patient['alerts'] as List),

                // Allergies
                _buildAllergiesSection(patient['allergies'] as List? ?? []),
                const SizedBox(height: 16),

                // Current medications
                _buildMedicationsSection(patient['medications'] as List? ?? []),
                const SizedBox(height: 16),

                // Medical history
                _buildMedicalHistorySection(patient['conditions'] as List? ?? []),
                const SizedBox(height: 16),

                // Recent vital signs
                _buildVitalSignsSection(patient['vitals'] as Map<String, dynamic>? ?? {}),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _clearPatientData,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _startConsultation,
                        icon: const Icon(Icons.medical_services),
                        label: const Text('New Consultation'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AfiCareTheme.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsCard(List alerts) {
    return Card(
      color: Colors.red.shade50,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  'Critical Alerts',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...alerts.map((alert) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 8, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alert.toString(),
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildAllergiesSection(List allergies) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Known Allergies',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (allergies.isEmpty)
              Text(
                'No known allergies',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allergies.map((allergy) => Chip(
                  backgroundColor: Colors.red.shade50,
                  avatar: Icon(
                    Icons.dangerous,
                    size: 16,
                    color: Colors.red.shade700,
                  ),
                  label: Text(
                    allergy.toString(),
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                )).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationsSection(List medications) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medication, color: AfiCareTheme.primaryGreen),
                const SizedBox(width: 8),
                const Text(
                  'Current Medications',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (medications.isEmpty)
              Text(
                'No active medications',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              ...medications.map((med) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AfiCareTheme.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(med.toString())),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalHistorySection(List conditions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: AfiCareTheme.primaryBlue),
                const SizedBox(width: 8),
                const Text(
                  'Medical History',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (conditions.isEmpty)
              Text(
                'No significant medical history',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              ...conditions.map((condition) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: AfiCareTheme.primaryBlue),
                    const SizedBox(width: 12),
                    Expanded(child: Text(condition.toString())),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalSignsSection(Map<String, dynamic> vitals) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.monitor_heart, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text(
                      'Latest Vital Signs',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Text(
                  vitals['date'] ?? 'Today',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildVitalCard(
                    'Temperature',
                    vitals['temperature'] ?? '36.8°C',
                    Icons.thermostat,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildVitalCard(
                    'Blood Pressure',
                    vitals['bloodPressure'] ?? '120/80',
                    Icons.favorite,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildVitalCard(
                    'Heart Rate',
                    vitals['heartRate'] ?? '72 bpm',
                    Icons.monitor_heart,
                    Colors.pink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildVitalCard(
                    'SpO2',
                    vitals['spo2'] ?? '98%',
                    Icons.air,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _onQRDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue != null) {
        _processQRCode(barcode.rawValue!);
        break;
      }
    }
  }

  void _processQRCode(String qrData) {
    // Parse QR data and load patient
    _loadMockPatientData('ML-NBO-847291');
  }

  void _verifyAccessCode(String code) {
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-character code'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Simulate API call
    Future.delayed(const Duration(seconds: 1), () {
      _loadMockPatientData('ML-NBO-847291');
    });
  }

  void _searchMedilinkId(String id) {
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a MediLink ID'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Simulate API call
    Future.delayed(const Duration(seconds: 1), () {
      _loadMockPatientData(id);
    });
  }

  void _loadMockPatientData(String medilinkId) {
    setState(() {
      _isLoading = false;
      _patientData = {
        'name': 'Jane Wanjiku Kamau',
        'medilinkId': medilinkId,
        'age': 34,
        'gender': 'Female',
        'phone': '+254 712 345 678',
        'alerts': [
          'High blood pressure - last reading 150/95 (Jan 28)',
          'Pending lab results from Jan 25',
        ],
        'allergies': ['Penicillin', 'Sulfa drugs'],
        'medications': [
          'Metformin 500mg - Twice daily',
          'Lisinopril 10mg - Once daily',
          'Vitamin D3 1000IU - Once daily',
        ],
        'conditions': [
          'Type 2 Diabetes (diagnosed 2022)',
          'Hypertension (diagnosed 2023)',
          'History of gestational diabetes (2020)',
        ],
        'vitals': {
          'date': 'Jan 28, 2026',
          'temperature': '36.8°C',
          'bloodPressure': '150/95',
          'heartRate': '78 bpm',
          'spo2': '97%',
        },
      };
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Patient records loaded successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _clearPatientData() {
    setState(() {
      _patientData = null;
      _accessCodeController.clear();
      _medilinkIdController.clear();
    });
  }

  void _startConsultation() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting new consultation...'),
      ),
    );
  }
}

/// Input formatter to convert text to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// Custom scanner overlay shape
class _ScannerOverlay extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const _ScannerOverlay({
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 0.5),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..moveTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final cutOutWidth = cutOutSize;
    final cutOutHeight = cutOutSize;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - cutOutWidth / 2 + borderOffset,
      rect.top + height / 2 - cutOutHeight / 2 + borderOffset,
      cutOutWidth - borderOffset * 2,
      cutOutHeight - borderOffset * 2,
    );

    canvas
      ..saveLayer(rect, backgroundPaint)
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
        boxPaint,
      )
      ..restore();

    final borderRect = RRect.fromRectAndRadius(
      cutOutRect,
      Radius.circular(borderRadius),
    );

    // Draw corners
    canvas.drawPath(
      Path()
        ..moveTo(borderRect.left, borderRect.top + borderLength)
        ..lineTo(borderRect.left, borderRect.top + borderRadius)
        ..arcToPoint(
          Offset(borderRect.left + borderRadius, borderRect.top),
          radius: Radius.circular(borderRadius),
        )
        ..lineTo(borderRect.left + borderLength, borderRect.top),
      borderPaint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(borderRect.right - borderLength, borderRect.top)
        ..lineTo(borderRect.right - borderRadius, borderRect.top)
        ..arcToPoint(
          Offset(borderRect.right, borderRect.top + borderRadius),
          radius: Radius.circular(borderRadius),
        )
        ..lineTo(borderRect.right, borderRect.top + borderLength),
      borderPaint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(borderRect.right, borderRect.bottom - borderLength)
        ..lineTo(borderRect.right, borderRect.bottom - borderRadius)
        ..arcToPoint(
          Offset(borderRect.right - borderRadius, borderRect.bottom),
          radius: Radius.circular(borderRadius),
        )
        ..lineTo(borderRect.right - borderLength, borderRect.bottom),
      borderPaint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(borderRect.left + borderLength, borderRect.bottom)
        ..lineTo(borderRect.left + borderRadius, borderRect.bottom)
        ..arcToPoint(
          Offset(borderRect.left, borderRect.bottom - borderRadius),
          radius: Radius.circular(borderRadius),
        )
        ..lineTo(borderRect.left, borderRect.bottom - borderLength),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) => this;
}
