import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/patient_tokens.dart';
import 'widgets/patient_ui.dart';

/// What a scanned QR turned out to be.
enum ScannedKind { ownMedilinkId, medilinkId, shareLink, other }

/// A scanned QR, read honestly: the scanner only says what the code is.
/// Scanning never verifies anyone and never shares a record, because no
/// AfiCare facility or provider QR exists yet for it to act on.
class ScannedCode {
  const ScannedCode(this.kind, this.raw, {this.value});

  final ScannedKind kind;
  final String raw;

  /// The MediLink ID or share code found in [raw], if any.
  final String? value;

  static final _medilinkId = RegExp(r'^ML-[A-Z0-9]+-[A-Z0-9]+$');
  static final _shareLink = RegExp(r'^https?://\S+/v/([A-Za-z0-9-]+)/?$');

  static ScannedCode parse(String raw, {String? ownMedilinkId}) {
    final text = raw.trim();
    final upper = text.toUpperCase();
    if (_medilinkId.hasMatch(upper)) {
      final own = ownMedilinkId != null && upper == ownMedilinkId.toUpperCase();
      return ScannedCode(own ? ScannedKind.ownMedilinkId : ScannedKind.medilinkId, text, value: upper);
    }
    final link = _shareLink.firstMatch(text);
    if (link != null) {
      return ScannedCode(ScannedKind.shareLink, text, value: link.group(1));
    }
    return ScannedCode(ScannedKind.other, text);
  }
}

class QRScanner extends StatefulWidget {
  const QRScanner({super.key});

  @override
  State<QRScanner> createState() => _QRScannerState();
}

class _QRScannerState extends State<QRScanner> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  ScannedCode? _result;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_result != null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _controller.start();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _controller.stop();
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PT.page,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PSubPageBar(
                title: 'Scan a QR code',
                actions: [
                  if (_result == null) ...[
                    _barButton(
                      icon: _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      tooltip: _torchOn ? 'Turn off torch' : 'Turn on torch',
                      onPressed: _toggleTorch,
                    ),
                    const SizedBox(width: 8),
                    _barButton(
                      icon: Icons.cameraswitch_rounded,
                      tooltip: 'Switch camera',
                      onPressed: () => _controller.switchCamera(),
                    ),
                  ],
                ],
              ),
              Expanded(child: _result == null ? _scannerView() : _resultView(_result!)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barButton({required IconData icon, required String tooltip, required VoidCallback onPressed}) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        fixedSize: const Size(42, 42),
        backgroundColor: PT.white,
        foregroundColor: PT.teal,
        side: const BorderSide(color: PT.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ── Camera ────────────────────────────────────────────────────────────

  Widget _scannerView() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(PT.rHero),
                child: ColoredBox(
                  color: const Color(0xFF0B2230),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                        errorBuilder: (context, error, _) => _cameraError(error),
                      ),
                      LayoutBuilder(
                        builder: (context, box) => DecoratedBox(
                          decoration: ShapeDecoration(
                            shape: QRScannerOverlayShape(
                              borderColor: const Color(0xFFD6ECE9),
                              borderRadius: 16,
                              borderLength: 30,
                              borderWidth: 6,
                              cutOutSize: box.maxWidth * 0.68,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Hold the code inside the frame.', style: PT.h3(), textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                  'The scanner tells you what a code is. It never shares your records '
                  'and it can\'t check you in at a facility.',
                  style: PT.sub(),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cameraError(MobileScannerException error) {
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'AfiCare isn\'t allowed to use your camera. Turn camera access on in your phone or browser settings, then try again.',
      MobileScannerErrorCode.unsupported => 'This device or browser can\'t scan QR codes.',
      _ => 'The camera couldn\'t start. Close other apps using it and try again.',
    };
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography_outlined, size: 44, color: Color(0xFFD6ECE9)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: PT.sub().copyWith(color: const Color(0xFFD6ECE9)),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_result != null) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      final own = context.read<AuthProvider>().currentUser?.medilinkId;
      _controller.stop();
      setState(() => _result = ScannedCode.parse(raw, ownMedilinkId: own));
      return;
    }
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    if (mounted) setState(() => _torchOn = !_torchOn);
  }

  void _scanAgain() {
    setState(() => _result = null);
    _controller.start();
  }

  // ── Result ────────────────────────────────────────────────────────────

  Widget _resultView(ScannedCode code) {
    final (String badge, PTone tone, String title, String body) = switch (code.kind) {
      ScannedKind.ownMedilinkId => (
          'Your MediLink ID',
          PTone.ok,
          'This is your own MediLink ID',
          'A health worker scans this to find your record. Scanning it here does nothing.',
        ),
      ScannedKind.medilinkId => (
          'MediLink ID',
          PTone.blue,
          'This is someone\'s MediLink ID',
          'Only health workers can open a record from a MediLink ID. You can\'t see this '
              'person\'s record, and they can\'t see yours.',
        ),
      ScannedKind.shareLink => (
          'Record-sharing link',
          PTone.blue,
          'This is an AfiCare record-sharing link',
          'Someone made it so a health worker could view their records. '
              'It doesn\'t open anything in your app.',
        ),
      ScannedKind.other => (
          'Not AfiCare',
          PTone.gray,
          'This isn\'t an AfiCare code',
          'AfiCare can\'t do anything with it. Only scan codes you trust.',
        ),
    };

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PBadge(badge, tone: tone),
                      const SizedBox(height: 12),
                      Text(title, style: PT.section()),
                      const SizedBox(height: 6),
                      Text(body, style: PT.sub()),
                      const SizedBox(height: 16),
                      Text('What the code says', style: PT.label()),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: PT.searchFill,
                          borderRadius: BorderRadius.circular(PT.rButton),
                        ),
                        child: SelectableText(
                          code.raw,
                          maxLines: 6,
                          style: PT.body().copyWith(fontFamily: 'monospace', fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PButton(
                          'Copy',
                          kind: PButtonKind.alt,
                          dense: true,
                          icon: Icons.copy_rounded,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: code.raw));
                            pToast(context, 'Copied');
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const PCallout(
                  title: 'Nothing was shared',
                  body: 'Scanning a code never sends your records anywhere. '
                      'To let a health worker see your records, use Share records.',
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: PButton(
                        'Scan another',
                        kind: PButtonKind.alt,
                        expand: true,
                        icon: Icons.qr_code_scanner_rounded,
                        onPressed: _scanAgain,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PButton(
                        'Share records',
                        expand: true,
                        onPressed: () => context.go('/patient/share'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Darkens everything outside a centred square and draws its corners.
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
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRect(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final borderOffset = borderWidth / 2;

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
      rect.left + rect.width / 2 - cutOutSize / 2 + borderOffset,
      rect.top + rect.height / 2 - cutOutSize / 2 + borderOffset,
      cutOutSize - borderOffset * 2,
      cutOutSize - borderOffset * 2,
    );

    canvas
      ..saveLayer(rect, backgroundPaint)
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)), boxPaint)
      ..restore();

    final r = RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius));
    final radius = Radius.circular(borderRadius);

    canvas
      ..drawPath(
        Path()
          ..moveTo(r.left, r.top + borderLength)
          ..lineTo(r.left, r.top + borderRadius)
          ..arcToPoint(Offset(r.left + borderRadius, r.top), radius: radius)
          ..lineTo(r.left + borderLength, r.top),
        borderPaint,
      )
      ..drawPath(
        Path()
          ..moveTo(r.right - borderLength, r.top)
          ..lineTo(r.right - borderRadius, r.top)
          ..arcToPoint(Offset(r.right, r.top + borderRadius), radius: radius)
          ..lineTo(r.right, r.top + borderLength),
        borderPaint,
      )
      ..drawPath(
        Path()
          ..moveTo(r.right, r.bottom - borderLength)
          ..lineTo(r.right, r.bottom - borderRadius)
          ..arcToPoint(Offset(r.right - borderRadius, r.bottom), radius: radius)
          ..lineTo(r.right - borderLength, r.bottom),
        borderPaint,
      )
      ..drawPath(
        Path()
          ..moveTo(r.left + borderLength, r.bottom)
          ..lineTo(r.left + borderRadius, r.bottom)
          ..arcToPoint(Offset(r.left, r.bottom - borderRadius), radius: radius)
          ..lineTo(r.left, r.bottom - borderLength),
        borderPaint,
      );
  }

  @override
  ShapeBorder scale(double t) {
    return QRScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
      borderRadius: borderRadius * t,
      borderLength: borderLength * t,
      cutOutSize: cutOutSize * t,
    );
  }
}
