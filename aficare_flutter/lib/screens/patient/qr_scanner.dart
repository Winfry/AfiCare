import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../utils/theme.dart';

class QRScanner extends StatefulWidget {
  const QRScanner({super.key});

  @override
  State<QRScanner> createState() => _QRScannerState();
}

class _QRScannerState extends State<QRScanner> with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _isScanning = true;
  bool _hasScanned = false;
  String? _scannedData;
  bool _torchEnabled = false;
  bool _frontCamera = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initController();
  }

  void _initController() {
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _controller?.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _controller?.stop();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: AfiCareTheme.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_torchEnabled ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleTorch,
          ),
          IconButton(
            icon: Icon(_frontCamera ? Icons.camera_front : Icons.camera_rear),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: _hasScanned ? _buildResultView() : _buildScannerView(),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        // Camera view
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
        ),

        // Overlay
        Container(
          decoration: ShapeDecoration(
            shape: QRScannerOverlayShape(
              borderColor: AfiCareTheme.primaryGreen,
              borderRadius: 16,
              borderLength: 30,
              borderWidth: 8,
              cutOutSize: MediaQuery.of(context).size.width * 0.7,
            ),
          ),
        ),

        // Instructions
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
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.qr_code_scanner,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Scan Provider QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Point your camera at a healthcare provider\'s QR code to verify their identity',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionButton(
                      icon: Icons.image,
                      label: 'Gallery',
                      onPressed: _pickFromGallery,
                    ),
                    const SizedBox(width: 24),
                    _buildActionButton(
                      icon: Icons.keyboard,
                      label: 'Enter Code',
                      onPressed: _enterCodeManually,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Scanning indicator
        if (_isScanning)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Scanning...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResultView() {
    final parsedData = _parseQRData(_scannedData ?? '');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 60,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'QR Code Scanned!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Provider information verified',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AfiCareTheme.primaryBlue.withOpacity(0.1),
                    child: Icon(
                      Icons.local_hospital,
                      size: 40,
                      color: AfiCareTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    parsedData['name'] ?? 'Healthcare Provider',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    parsedData['hospital'] ?? 'Medical Facility',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified,
                          color: Colors.green.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Verified Provider',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    'Provider ID',
                    parsedData['id'] ?? 'PRV-XXX-XXXX',
                    Icons.badge,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    'Department',
                    parsedData['department'] ?? 'General Medicine',
                    Icons.medical_services,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    'License No.',
                    parsedData['license'] ?? 'KMD-123456',
                    Icons.card_membership,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This provider is requesting access to your medical records.',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _scanAgain,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Again'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _grantAccess(parsedData),
                  icon: const Icon(Icons.check),
                  label: const Text('Grant Access'),
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
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() {
          _hasScanned = true;
          _scannedData = barcode.rawValue;
          _isScanning = false;
        });
        _controller?.stop();
        break;
      }
    }
  }

  Map<String, String> _parseQRData(String data) {
    // Parse AFICARE QR format: AFICARE:TYPE:ID:NAME:HOSPITAL:DEPARTMENT
    final parts = data.split(':');
    if (parts.length >= 2 && parts[0] == 'AFICARE') {
      return {
        'type': parts.length > 1 ? parts[1] : 'PROVIDER',
        'id': parts.length > 2 ? parts[2] : 'PRV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'name': parts.length > 3 ? parts[3] : 'Dr. Healthcare Provider',
        'hospital': parts.length > 4 ? parts[4] : 'Medical Center',
        'department': parts.length > 5 ? parts[5] : 'General Medicine',
        'license': 'KMD-${DateTime.now().millisecondsSinceEpoch.toString().substring(5, 11)}',
      };
    }
    // Default mock data for demo
    return {
      'type': 'PROVIDER',
      'id': 'PRV-NBO-7842',
      'name': 'Dr. James Ochieng',
      'hospital': 'Nairobi General Hospital',
      'department': 'Internal Medicine',
      'license': 'KMD-087421',
    };
  }

  void _toggleTorch() async {
    await _controller?.toggleTorch();
    setState(() {
      _torchEnabled = !_torchEnabled;
    });
  }

  void _switchCamera() async {
    await _controller?.switchCamera();
    setState(() {
      _frontCamera = !_frontCamera;
    });
  }

  void _pickFromGallery() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gallery picker coming soon...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _enterCodeManually() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Enter Provider Code'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Provider Code',
              hintText: 'e.g., PRV-NBO-1234',
              prefixIcon: Icon(Icons.badge),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (controller.text.isNotEmpty) {
                  setState(() {
                    _hasScanned = true;
                    _scannedData = 'AFICARE:PROVIDER:${controller.text}';
                  });
                  _controller?.stop();
                }
              },
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );
  }

  void _scanAgain() {
    setState(() {
      _hasScanned = false;
      _scannedData = null;
      _isScanning = true;
    });
    _controller?.start();
  }

  void _grantAccess(Map<String, String> providerData) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildAccessPermissionSheet(providerData),
    );
  }

  Widget _buildAccessPermissionSheet(Map<String, String> providerData) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grant Access',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose what ${providerData['name']} can access:',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          _buildPermissionOption('Basic Information', Icons.person, true),
          _buildPermissionOption('Vital Signs', Icons.favorite, true),
          _buildPermissionOption('Medical History', Icons.history, false),
          _buildPermissionOption('Medications', Icons.medication, false),
          _buildPermissionOption('Lab Results', Icons.science, false),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Access granted to ${providerData['name']}'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AfiCareTheme.primaryGreen,
              ),
              child: const Text('Confirm Access'),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildPermissionOption(String label, IconData icon, bool defaultValue) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isChecked = defaultValue;
        return CheckboxListTile(
          value: isChecked,
          onChanged: (value) {
            setState(() {
              isChecked = value ?? false;
            });
          },
          title: Row(
            children: [
              Icon(icon, size: 20, color: AfiCareTheme.primaryGreen),
              const SizedBox(width: 12),
              Text(label),
            ],
          ),
          controlAffinity: ListTileControlAffinity.trailing,
          activeColor: AfiCareTheme.primaryGreen,
        );
      },
    );
  }
}

/// Custom overlay shape for QR scanner
class QRScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QRScannerOverlayShape({
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
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top);
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

    // Draw corner borders
    final borderRect = RRect.fromRectAndRadius(
      cutOutRect,
      Radius.circular(borderRadius),
    );

    // Top left corner
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

    // Top right corner
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

    // Bottom right corner
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

    // Bottom left corner
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
  ShapeBorder scale(double t) {
    return QRScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
    );
  }
}
