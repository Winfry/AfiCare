import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../presentation/auth/widgets/auth_form_container.dart';
import '../presentation/auth/widgets/auth_page_header.dart';
import '../presentation/auth/widgets/auth_split_layout.dart';
import '../providers/facility_admin_request_provider.dart';

/// "Register your facility + name who should administer it" flow. No
/// account is created here -- an applicant only has a name/email on
/// file until a platform admin approves the request, at which point
/// invite-facility-admin sends them a real invite email and creates
/// their account directly as role='facility_admin' (never 'patient').
/// See 017_facility_admin_invite_flow.sql.
class FacilityAdminRegistrationScreen extends StatefulWidget {
  const FacilityAdminRegistrationScreen({super.key});

  @override
  State<FacilityAdminRegistrationScreen> createState() =>
      _FacilityAdminRegistrationScreenState();
}

class _FacilityAdminRegistrationScreenState
    extends State<FacilityAdminRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Facility fields
  final _facilityNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _facilityEmailController = TextEditingController();
  final _countyController = TextEditingController();
  final _subCountyController = TextEditingController();
  String _selectedType = 'clinic';

  // Applicant/nominated-admin fields (contact info only -- no password)
  final _fullNameController = TextEditingController();
  final _workEmailController = TextEditingController();
  final _titleController = TextEditingController();

  bool _isLoading = false;
  bool _submitted = false;
  String? _submittedFacilityName;
  String? _submittedEmail;

  static const _facilityTypes = [
    'hospital',
    'clinic',
    'health_centre',
    'dispensary',
    'nursing_home',
    'other',
  ];

  @override
  void dispose() {
    _facilityNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _facilityEmailController.dispose();
    _countyController.dispose();
    _subCountyController.dispose();
    _fullNameController.dispose();
    _workEmailController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final facilityRequests = context.read<FacilityAdminRequestProvider>();
    final supabase = Supabase.instance.client;

    try {
      final facilityResp = await supabase
          .from('facilities')
          .insert({
            'name': _facilityNameController.text.trim(),
            'type': _selectedType,
            'county': _countyController.text.trim().isEmpty
                ? null
                : _countyController.text.trim(),
            'sub_county': _subCountyController.text.trim().isEmpty
                ? null
                : _subCountyController.text.trim(),
            'address': _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
            'phone': _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            'email': _facilityEmailController.text.trim().isEmpty
                ? null
                : _facilityEmailController.text.trim(),
          })
          .select('id')
          .single();

      final facilityId = facilityResp['id'] as String;

      final ok = await facilityRequests.submitRequest(
        facilityId: facilityId,
        applicantName: _fullNameController.text.trim(),
        applicantEmail: _workEmailController.text.trim(),
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
      );

      if (!ok) {
        throw Exception(facilityRequests.error ?? 'Could not submit your request');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _submitted = true;
          _submittedFacilityName = _facilityNameController.text.trim();
          _submittedEmail = _workEmailController.text.trim();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthSplitLayout(
      brandHeadline: 'Onboard your hospital or clinic.',
      brandSubtitle: 'Register your facility and nominate an administrator -- your team gets one connected record system across every provider.',
      brandPhotoUrl: 'assets/images/AdminRegisterScreen.webp',
      child: AuthFormContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthPageHeader(
              title: 'Register your facility',
              subtitle: 'Tell us about your facility and who should administer it.',
              onBack: () => context.go('/register'),
            ),
            _submitted ? _buildSubmittedView() : _buildForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmittedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.hourglass_top, size: 64, color: Color(0xFFFB8C00)),
        const SizedBox(height: 16),
        Text(
          'Your request is pending review',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "Thanks for registering ${_submittedFacilityName ?? 'your facility'}. "
          "An AfiCare admin will review your request, and if approved, "
          "${_submittedEmail ?? 'the email you gave us'} will receive an invite "
          "to activate the admin account -- no account exists until then.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.go('/login'),
          child: const Text('Back to AfiCare'),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "An "
            "AfiCare admin will review and approve the request -- the "
            "nominated admin gets a real invite email to activate their "
            "account once approved. No account is created until then.",
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          Text(
            'Facility details',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _facilityNameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Facility Name *',
              prefixIcon: Icon(Icons.local_hospital),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Facility name is required' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(
              labelText: 'Facility Type',
              prefixIcon: Icon(Icons.category),
            ),
            items: _facilityTypes
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.replaceAll('_', ' ').toUpperCase()),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedType = v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _countyController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'County',
              prefixIcon: Icon(Icons.location_city),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _subCountyController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Sub-County',
              prefixIcon: Icon(Icons.map),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Physical Address',
              prefixIcon: Icon(Icons.home),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Facility Phone Number',
              prefixIcon: Icon(Icons.phone),
              hintText: '+254...',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _facilityEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Facility Email Address',
              prefixIcon: Icon(Icons.email),
            ),
            validator: (v) {
              if (v != null && v.isNotEmpty && !v.contains('@')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),

          const SizedBox(height: 28),
          Text(
            'Who should administer this facility?',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "This can be you or someone else at your facility. They'll get an "
            "invite email to set up their account once approved -- no account "
            "is created until then.",
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _fullNameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Full Name *',
              prefixIcon: Icon(Icons.person),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Title (optional)',
              prefixIcon: Icon(Icons.badge_outlined),
              hintText: 'e.g. Operations Manager',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _workEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Work Email *',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Work email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Submit for Review'),
          ),
        ],
      ),
    );
  }
}
