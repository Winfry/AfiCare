import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../models/receipt_model.dart';

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
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.canopy)));
    }

    final totalSpent = _receipts.fold<double>(0, (s, r) => s + (r.totalAmount ?? 0));

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
            title: const Text('Receipts & Expenses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
      ),
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
                  ? Image.network(receipt.imageUrl!, fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey.shade100,
                      child: Icon(Icons.receipt_rounded, color: Colors.grey.shade400, size: 24),
                    ),
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

  Future<void> _pickReceipt(ImageSource source) async {
    final picked = await _imagePicker.pickImage(source: source, maxWidth: 1920, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isUploading = true);

    final patientId = _supabase.auth.currentUser?.id;
    if (patientId == null) return;

    try {
      final ext = picked.path.split('.').last;
      final fileName = 'receipts/$patientId/${const Uuid().v4()}.$ext';
      final bytes = await picked.readAsBytes();

      await _supabase.storage.from('media').uploadBinary(fileName, bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'));

      final imageUrl = _supabase.storage.from('media').getPublicUrl(fileName);

      if (mounted) {
        _showReceiptDetailSheet(imageUrl: imageUrl, patientId: patientId);
      }
    } catch (e) {
      debugPrint('Error uploading receipt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: const Color(0xFFE53935)),
        );
      }
    }

    setState(() => _isUploading = false);
  }

  void _showReceiptDetailSheet({required String imageUrl, required String patientId}) {
    final facilityCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String serviceType = 'Consultation';
    String paymentMethod = 'cash';

    showModalBottomSheet(
      context: context,
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
                        await _supabase.from('receipts').insert({
                          'id': const Uuid().v4(),
                          'patient_id': patientId,
                          'image_url': imageUrl,
                          'facility_name': facilityCtrl.text.isNotEmpty ? facilityCtrl.text : null,
                          'total_amount': double.tryParse(amountCtrl.text),
                          'service_type': serviceType,
                          'payment_method': paymentMethod,
                          'date': DateTime.now().toIso8601String(),
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadReceipts();
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
