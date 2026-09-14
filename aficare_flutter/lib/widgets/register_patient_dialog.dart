import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/facility_patient_provider.dart';

/// Shared "Register Patient" form, used by both the Patients screen and
/// OPD Queue's "New Walk-in" path. Extracted rather than duplicated (it's
/// a ~140-line form) so a field added to one caller's flow can't silently
/// drift from the other's. Returns the new patient's id on success, or
/// null if the dialog was cancelled or the registration failed.
Future<String?> showRegisterPatientDialog(BuildContext context, {required String facilityId}) {
  final nameCtl = TextEditingController();
  final phoneCtl = TextEditingController();
  final fileNumberCtl = TextEditingController();
  final allergiesCtl = TextEditingController();
  DateTime? dob;
  String? gender;
  var shaStatus = 'unknown';
  var submitting = false;

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Register Patient'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(labelText: 'Full Name *', isDense: true),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime(2000),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => dob = picked);
                        },
                        child: Text(dob == null
                            ? 'Date of Birth'
                            : '${dob!.year}-${dob!.month.toString().padLeft(2, '0')}-${dob!.day.toString().padLeft(2, '0')}'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: gender,
                        isDense: true,
                        decoration: const InputDecoration(labelText: 'Gender', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'male', child: Text('Male')),
                          DropdownMenuItem(value: 'female', child: Text('Female')),
                          DropdownMenuItem(value: 'other', child: Text('Other')),
                        ],
                        onChanged: (v) => setState(() => gender = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtl,
                  decoration: const InputDecoration(labelText: 'Phone', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: fileNumberCtl,
                  decoration: const InputDecoration(labelText: 'File / OP Number', isDense: true),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: shaStatus,
                  isDense: true,
                  decoration: const InputDecoration(labelText: 'SHA Status', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
                    DropdownMenuItem(value: 'not_registered', child: Text('Not Registered')),
                    DropdownMenuItem(value: 'registered', child: Text('Registered')),
                  ],
                  onChanged: (v) => setState(() => shaStatus = v ?? shaStatus),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: allergiesCtl,
                  decoration: const InputDecoration(labelText: 'Allergies (comma-separated)', isDense: true),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: submitting ? null : () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: submitting
                ? null
                : () async {
                    if (nameCtl.text.trim().isEmpty) return;
                    setState(() => submitting = true);
                    final provider = ctx.read<FacilityPatientProvider>();
                    final newId = await provider.registerPatient(
                      facilityId: facilityId,
                      fullName: nameCtl.text.trim(),
                      dateOfBirth: dob,
                      gender: gender,
                      phone: phoneCtl.text.trim().isEmpty ? null : phoneCtl.text.trim(),
                      fileNumber: fileNumberCtl.text.trim().isEmpty ? null : fileNumberCtl.text.trim(),
                      shaStatus: shaStatus,
                      allergies: allergiesCtl.text
                          .split(',')
                          .map((a) => a.trim())
                          .where((a) => a.isNotEmpty)
                          .toList(),
                    );
                    if (ctx.mounted) {
                      if (newId == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Failed: ${provider.error}')),
                        );
                        setState(() => submitting = false);
                        return;
                      }
                      Navigator.pop(ctx, newId);
                    }
                  },
            child: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Register'),
          ),
        ],
      ),
    ),
  );
}
