import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/provider_verification_provider.dart';
import '../models/provider_credential_model.dart';
import '../utils/theme.dart';

/// Self-service "become a verified provider" request. Any logged-in user
/// can submit a license for review; nothing about their access changes
/// until an admin approves it (see admin_verify_provider_license).
class ProviderVerificationRequestScreen extends StatefulWidget {
  const ProviderVerificationRequestScreen({super.key});

  @override
  State<ProviderVerificationRequestScreen> createState() => _ProviderVerificationRequestScreenState();
}

class _ProviderVerificationRequestScreenState extends State<ProviderVerificationRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _licenseController = TextEditingController();
  final _specialtyController = TextEditingController();
  String _selectedRole = 'doctor';
  bool _isSubmitting = false;

  static const _roles = ['doctor', 'nurse', 'chw', 'radiologist'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProviderVerificationProvider>().loadMyRequest();
    });
  }

  @override
  void dispose() {
    _licenseController.dispose();
    _specialtyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final provider = context.read<ProviderVerificationProvider>();
    final ok = await provider.submitRequest(
      licenseNumber: _licenseController.text.trim(),
      specialty: _specialtyController.text.trim().isEmpty ? null : _specialtyController.text.trim(),
      requestedRole: _selectedRole,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit: ${provider.error}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProviderVerificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Verification'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AfiCareTheme.primaryGreen,
      ),
      body: SafeArea(
        child: provider.isLoading && provider.myRequest == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: provider.myRequest != null && provider.myRequest!.verificationStatus != VerificationStatus.rejected
                    ? _buildStatusView(provider.myRequest!)
                    : _buildForm(provider.myRequest),
              ),
      ),
    );
  }

  Widget _buildStatusView(ProviderCredentialModel request) {
    final isVerified = request.verificationStatus == VerificationStatus.verified;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          isVerified ? Icons.verified : Icons.hourglass_top,
          size: 64,
          color: isVerified ? const Color(0xFF43A047) : const Color(0xFFFB8C00),
        ),
        const SizedBox(height: 16),
        Text(
          isVerified ? 'You are a verified provider' : 'Your request is under review',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          isVerified
              ? 'Your account has been promoted to ${_capitalize(request.requestedRole)}. An admin can now link you to any facility you work at.'
              : 'An admin is reviewing your submitted license. You\'ll be able to act as a ${_capitalize(request.requestedRole)} once approved.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('License #: ${request.licenseNumber}'),
                if (request.specialty != null && request.specialty!.isNotEmpty)
                  Text('Specialty: ${request.specialty}'),
                Text('Requested role: ${_capitalize(request.requestedRole)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(onPressed: () => context.pop(), child: const Text('Back')),
      ],
    );
  }

  Widget _buildForm(ProviderCredentialModel? previousRequest) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Apply to become a verified provider',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AfiCareTheme.primaryGreen,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Submit your medical license so an admin can verify you as real medical staff. '
            'You\'ll keep your current access until it\'s approved.',
            style: TextStyle(color: Colors.grey[600]),
          ),
          if (previousRequest != null && previousRequest.verificationStatus == VerificationStatus.rejected) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Your previous request was rejected'
                '${previousRequest.rejectionReason != null && previousRequest.rejectionReason!.isNotEmpty ? ': ${previousRequest.rejectionReason}' : '.'} '
                'You can resubmit below.',
                style: const TextStyle(color: Color(0xFFE53935)),
              ),
            ),
          ],
          const SizedBox(height: 24),
          TextFormField(
            controller: _licenseController,
            decoration: const InputDecoration(
              labelText: 'License / registration number *',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'License number is required' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'Requesting role',
              prefixIcon: Icon(Icons.work_outline),
            ),
            items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(_capitalize(r)))).toList(),
            onChanged: (v) => setState(() => _selectedRole = v ?? 'doctor'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _specialtyController,
            decoration: const InputDecoration(
              labelText: 'Specialty (optional)',
              prefixIcon: Icon(Icons.local_hospital_outlined),
              hintText: 'e.g. Cardiology',
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Submit for review'),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
        ],
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
