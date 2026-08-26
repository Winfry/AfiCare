import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../models/caregiver_model.dart';

class CaregiverPortalScreen extends StatefulWidget {
  const CaregiverPortalScreen({super.key});

  @override
  State<CaregiverPortalScreen> createState() => _CaregiverPortalScreenState();
}

class _CaregiverPortalScreenState extends State<CaregiverPortalScreen> {
  final _supabase = Supabase.instance.client;
  List<CaregiverAccess> _grantedAccess = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Access I've granted to others
      final granted = await _supabase
          .from('caregiver_access')
          .select()
          .eq('granted_by_patient_id', userId)
          .order('granted_at', ascending: false);
      _grantedAccess = (granted as List).map((j) => CaregiverAccess.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error loading caregiver access: $e');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not load caregiver access: $e'), backgroundColor: Colors.red),
            );
          }
        });
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.canopy)));
    }

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
            title: const Text('Caregiver Access', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            actions: [
              TextButton.icon(
                onPressed: _showGrantAccessSheet,
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Grant', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Grant access codes to family members or caregivers so they can view your health records, book appointments, or access emergency information on your behalf.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Granted Access', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),

                  if (_grantedAccess.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderSubtle)),
                      child: Text('No access granted yet. Share an access code with your caregiver.',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                    )
                  else
                    ...(_grantedAccess.map((a) => _accessCard(a))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accessCard(CaregiverAccess access) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: access.isActive ? AppColors.borderSubtle : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (access.isActive ? AppColors.canopy : Colors.grey).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_add_rounded, color: access.isActive ? AppColors.canopy : Colors.grey, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(CaregiverAccess.accessLevelLabel(access.accessLevel),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(access.accessCode, style: TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.canopy)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: access.isActive ? const Color(0xFFE8F5E9) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(access.isActive ? 'Active' : 'Revoked',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: access.isActive ? const Color(0xFF2E7D32) : Colors.grey)),
              ),
            ],
          ),
          if (access.expiresAt != null) ...[
            const SizedBox(height: 8),
            Text('Expires: ${access.expiresAt!.day}/${access.expiresAt!.month}/${access.expiresAt!.year}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
          if (access.isActive) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => _revokeAccess(access),
                  child: const Text('Revoke', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showGrantAccessSheet() {
    String accessLevel = 'full';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Grant Access', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 6),
              Text('Choose what the caregiver can access', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              const SizedBox(height: 16),

              ...CaregiverAccess.accessLevelLabel('full').isNotEmpty
                  ? ['full', 'medical_only', 'appointments_only', 'emergency_only'].map((level) => RadioListTile<String>(
                        title: Text(CaregiverAccess.accessLevelLabel(level), style: const TextStyle(fontSize: 14)),
                        value: level,
                        groupValue: accessLevel,
                        onChanged: (v) => setSheetState(() => accessLevel = v!),
                        activeColor: AppColors.canopy,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ))
                  : [],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final userId = _supabase.auth.currentUser?.id;
                    if (userId == null) return;
                    final code = CaregiverAccess.generateAccessCode();

                    try {
                      await _supabase.from('caregiver_access').insert({
                        'id': const Uuid().v4(),
                        'caregiver_user_id': 'pending',
                        'dependent_patient_id': userId,
                        'access_code': code,
                        'access_level': accessLevel,
                        'is_active': true,
                        'granted_by_patient_id': userId,
                        'granted_at': DateTime.now().toIso8601String(),
                      });

                      if (mounted) {
                        Navigator.pop(ctx);
                        _loadAccess();
                        showDialog(
                          context: context,
                          builder: (dlgCtx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('Access Code Generated'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Share this code with your caregiver:',
                                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                                const SizedBox(height: 12),
                                Text(code, style: TextStyle(fontFamily: 'monospace', fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.canopy)),
                                const SizedBox(height: 8),
                                Text(CaregiverAccess.accessLevelLabel(accessLevel),
                                    style: TextStyle(color: Colors.grey.shade500)),
                              ],
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Done')),
                            ],
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error granting access: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.canopy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Generate Access Code', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _revokeAccess(CaregiverAccess access) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Access?'),
        content: const Text('The caregiver will no longer be able to use this access code.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Revoke', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _supabase
            .from('caregiver_access')
            .update({'is_active': false}).eq('id', access.id);
        _loadAccess();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error revoking access: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
