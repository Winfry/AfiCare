import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../models/receipt_model.dart';
import 'widgets/patient_ui.dart';

class ReceiptUploadScreen extends StatefulWidget {
  const ReceiptUploadScreen({super.key});

  @override
  State<ReceiptUploadScreen> createState() => _ReceiptUploadScreenState();
}

class _ReceiptUploadScreenState extends State<ReceiptUploadScreen> {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  List<Receipt> _receipts = [];
  bool _isLoading = true;
  bool _isUploading = false;

  /// Receipts live in the private 'receipts' bucket (042), in a folder
  /// named after the account id. receipts.image_url holds the path in the
  /// bucket, and the picture is shown through a short-lived signed link.
  static const _bucket = 'receipts';

  /// Signed links being fetched or fetched, by path, so a rebuild doesn't
  /// ask again.
  final Map<String, Future<String>> _signedUrls = {};

  Future<String> _signedUrl(String path) =>
      _signedUrls[path] ??= _supabase.storage.from(_bucket).createSignedUrl(path, 3600);

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    final patientId = _supabase.auth.currentUser?.id;
    if (patientId == null) return;
    try {
      final data = await _supabase
          .from('receipts')
          .select()
          .eq('patient_id', patientId)
          .order('created_at', ascending: false)
          .limit(50);
      _receipts = (data as List).map((j) => Receipt.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error loading receipts: $e');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not load receipts: $e'), backgroundColor: Colors.red),
            );
          }
        });
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const PLoadingPage();

    final totalSpent = _receipts.fold<double>(0, (s, r) => s + (r.totalAmount ?? 0));

    return PSliverPage(
      eyebrow: 'What care costs',
      title: 'Receipts',
      subtitle: 'Keep every receipt together, ready for a claim.',
      slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.canopy, const Color(0xFF24456B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Healthcare Spending', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('KES ${totalSpent.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('${_receipts.length} receipts uploaded', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(child: _uploadButton('Take Photo', Icons.camera_alt_rounded, () => _pickReceipt(ImageSource.camera))),
                      const SizedBox(width: 10),
                      Expanded(child: _uploadButton('Gallery', Icons.photo_library_rounded, () => _pickReceipt(ImageSource.gallery))),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Text('Receipts', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),

                  if (_receipts.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderSubtle)),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No receipts yet', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Upload receipts to track healthcare spending',
                              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    ...(_receipts.map((r) => _receiptCard(r))),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _uploadButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: _isUploading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _isUploading ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: _isUploading
            ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.canopy)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.canopy, size: 20),
                  const SizedBox(width: 8),
                  Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 14)),
                ],
              ),
      ),
    );
  }

  Widget _receiptCard(Receipt receipt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderSubtle)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56, height: 56,
              child: receipt.imageUrl != null
                  ? _thumbnail(receipt.imageUrl!)
                  : _noPicture(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(receipt.facilityName ?? 'Unknown Facility',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(receipt.serviceType ?? 'Healthcare',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                Text(
                    '${receipt.date.day}/${receipt.date.month}/${receipt.date.year}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('KES ${(receipt.totalAmount ?? 0).toStringAsFixed(0)}',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.canopy)),
              if (receipt.paymentMethod != null)
                Text(Receipt.paymentMethodLabel(receipt.paymentMethod!),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noPicture() => Container(
        color: Colors.grey.shade100,
        child: Icon(Icons.receipt_rounded, color: Colors.grey.shade400, size: 24),
      );

  Widget _thumbnail(String stored) {
    // Older rows could hold a full web address; new ones hold a path.
    if (stored.startsWith('http')) {
      return Image.network(stored, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _noPicture());
    }
    return FutureBuilder<String>(
      future: _signedUrl(stored),
      builder: (context, snap) => snap.hasData
          ? Image.network(snap.data!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _noPicture())
          : _noPicture(),
    );
  }

  static String _contentTypeFor(String ext) => switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => 'image/jpeg',
      };

  Future<void> _pickReceipt(ImageSource source) async {
    final picked = await _imagePicker.pickImage(source: source, maxWidth: 1920, imageQuality: 85);
    if (picked == null) return;

    final patientId = _supabase.auth.currentUser?.id;
    if (patientId == null) return;

    setState(() => _isUploading = true);
    String? path;
    try {
      // On the web picked.path is a blob address, so the name is used.
      final name = picked.name.toLowerCase();
      final ext = name.contains('.') ? name.split('.').last : 'jpg';
      final contentType = picked.mimeType ?? _contentTypeFor(ext);
      path = '$patientId/${const Uuid().v4()}.$ext';
      final bytes = await picked.readAsBytes();

      await _supabase.storage.from(_bucket).uploadBinary(path, bytes,
          fileOptions: FileOptions(contentType: contentType));
    } catch (e) {
      debugPrint('Error uploading receipt: $e');
      path = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("We couldn't upload that picture. Please check your connection and try again."),
            backgroundColor: Color(0xFFE53935),
          ),
        );
      }
    }

    if (mounted) setState(() => _isUploading = false);
    if (path != null && mounted) {
      final saved = await _showReceiptDetailSheet(imagePath: path, patientId: patientId);
      // Closed without saving: don't leave the picture behind.
      if (saved != true) {
        try {
          await _supabase.storage.from(_bucket).remove([path]);
        } catch (e) {
          debugPrint('Removing an unsaved receipt picture failed: $e');
        }
      }
    }
  }

  /// Returns true once the receipt is saved.
  Future<bool?> _showReceiptDetailSheet({required String imagePath, required String patientId}) {
    final facilityCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String serviceType = 'Consultation';
    String paymentMethod = 'cash';

    return showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Receipt Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(height: 16),
                  _field('Facility Name', facilityCtrl),
                  const SizedBox(height: 12),
                  _field('Amount (KES)', amountCtrl, keyboard: TextInputType.number),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: serviceType,
                    decoration: const InputDecoration(labelText: 'Service Type', border: OutlineInputBorder(), isDense: true),
                    items: Receipt.serviceTypeOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setSheetState(() => serviceType = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder(), isDense: true),
                    items: Receipt.paymentMethodOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (v) => setSheetState(() => paymentMethod = v!),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await _supabase.from('receipts').insert({
                            'id': const Uuid().v4(),
                            'patient_id': patientId,
                            'image_url': imagePath,
                            'facility_name': facilityCtrl.text.trim().isNotEmpty ? facilityCtrl.text.trim() : null,
                            'total_amount': double.tryParse(amountCtrl.text.trim().replaceAll(',', '')),
                            'service_type': serviceType,
                            'payment_method': paymentMethod,
                            'date': DateTime.now().toIso8601String().split('T').first,
                          });
                          if (ctx.mounted) Navigator.pop(ctx, true);
                          _loadReceipts();
                        } catch (e) {
                          debugPrint('receipt_upload_screen: saving receipt failed: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("We couldn't save this receipt. Please check your connection and try again."),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.canopy, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Save Receipt', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
    );
  }
}
