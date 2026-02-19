import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/theme.dart';

class FacilityRegistrationScreen extends StatefulWidget {
  const FacilityRegistrationScreen({super.key});

  @override
  State<FacilityRegistrationScreen> createState() =>
      _FacilityRegistrationScreenState();
}

class _FacilityRegistrationScreenState
    extends State<FacilityRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _countyController = TextEditingController();
  final _subCountyController = TextEditingController();

  String _selectedType = 'clinic';
  bool _isLoading = false;

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
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _countyController.dispose();
    _subCountyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('facilities').insert({
        'name': _nameController.text.trim(),
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
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Facility registered successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/register');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Facility'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AfiCareTheme.primaryGreen,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Health Facility Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AfiCareTheme.primaryGreen,
                        ),
                  ),
                ),
                const SizedBox(height: 24),

                // Facility Name
                Semantics(
                  label: 'Facility name, required',
                  child: TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Facility Name *',
                      prefixIcon: Icon(Icons.local_hospital),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                ),

                const SizedBox(height: 16),

                // Facility Type
                Semantics(
                  label: 'Facility type',
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Facility Type',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: _facilityTypes
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                t.replaceAll('_', ' ').toUpperCase(),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedType = v!),
                  ),
                ),

                const SizedBox(height: 16),

                // County
                Semantics(
                  label: 'County',
                  child: TextFormField(
                    controller: _countyController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'County',
                      prefixIcon: Icon(Icons.location_city),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Sub-County
                Semantics(
                  label: 'Sub-county',
                  child: TextFormField(
                    controller: _subCountyController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Sub-County',
                      prefixIcon: Icon(Icons.map),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Address
                Semantics(
                  label: 'Physical address',
                  child: TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Physical Address',
                      prefixIcon: Icon(Icons.home),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Phone
                Semantics(
                  label: 'Facility phone number',
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone),
                      hintText: '+254...',
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Email
                Semantics(
                  label: 'Facility email address',
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (v) {
                      if (v != null && v.isNotEmpty && !v.contains('@')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 32),

                Semantics(
                  button: true,
                  label: 'Register facility button',
                  child: ElevatedButton(
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
                        : const Text('Register Facility'),
                  ),
                ),

                const SizedBox(height: 16),

                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('Back to Registration'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
