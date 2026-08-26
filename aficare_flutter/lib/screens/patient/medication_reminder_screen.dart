import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../models/medication_reminder_model.dart';
import '../../services/medication_reminder_service.dart';

class MedicationReminderScreen extends StatefulWidget {
  const MedicationReminderScreen({super.key});

  @override
  State<MedicationReminderScreen> createState() => _MedicationReminderScreenState();
}

class _MedicationReminderScreenState extends State<MedicationReminderScreen> {
  final _supabase = Supabase.instance.client;
  final _service = MedicationReminderService();
  List<MedicationReminder> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service.init();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final patientId = _supabase.auth.currentUser?.id;
    if (patientId == null) return;

    final reminders = await _service.loadReminders(patientId);
    if (mounted) setState(() { _reminders = reminders; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.canopy)),
      );
    }

    final active = _reminders.where((r) => r.isActive).toList();
    final inactive = _reminders.where((r) => !r.isActive).toList();

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
            title: const Text('Medication Reminders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            actions: [
              TextButton.icon(
                onPressed: () => _showAddSheet(),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  if (_reminders.isEmpty)
                    _buildEmptyState()
                  else ...[
                    // Stats
                    Row(
                      children: [
                        _statCard('${active.length}', 'Active', Icons.alarm_rounded, const Color(0xFF2E7D32)),
                        const SizedBox(width: 12),
                        _statCard('${inactive.length}', 'Paused', Icons.pause_circle_outline, Colors.grey),
                        const SizedBox(width: 12),
                        _statCard('${_reminders.length}', 'Total', Icons.medication_rounded, AppColors.canopy),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Active reminders
                    if (active.isNotEmpty) ...[
                      const Text('Active', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 8),
                      ...active.map((r) => _buildReminderCard(r)),
                      const SizedBox(height: 16),
                    ],

                    // Inactive reminders
                    if (inactive.isNotEmpty) ...[
                      Text('Paused', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.grey.shade500)),
                      const SizedBox(height: 8),
                      ...inactive.map((r) => _buildReminderCard(r)),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          const Text('💊', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('No Reminders Yet', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            'Set up medication reminders so you never miss a dose.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showAddSheet,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create First Reminder'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.canopy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(MedicationReminder reminder) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: reminder.isActive ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: reminder.isActive ? AppColors.borderSubtle : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (reminder.isActive ? AppColors.canopy : Colors.grey).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(MedicationReminder.frequencyIcon(reminder.frequency), style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reminder.medicationName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text('${reminder.dosage} • ${MedicationReminder.frequencyLabel(reminder.frequency)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                if (reminder.times.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: reminder.times.map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.canopy.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(t.formatted, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.canopy)),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _handleAction(v, reminder),
            icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade400),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'toggle', child: Text(reminder.isActive ? 'Pause' : 'Resume')),
              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
    );
  }

  void _handleAction(String action, MedicationReminder reminder) async {
    final patientId = _supabase.auth.currentUser?.id;
    if (patientId == null) return;

    switch (action) {
      case 'toggle':
        await _service.toggleReminder(reminder.id, !reminder.isActive);
        _loadReminders();
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Reminder?'),
            content: Text('Remove ${reminder.medicationName} reminder?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (confirm == true) {
          await _service.deleteReminder(reminder.id);
          _loadReminders();
        }
        break;
    }
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddReminderSheet(
        onComplete: () => _loadReminders(),
      ),
    );
  }
}

class _AddReminderSheet extends StatefulWidget {
  final VoidCallback onComplete;
  const _AddReminderSheet({required this.onComplete});

  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  final _supabase = Supabase.instance.client;
  final _medNameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  String _frequency = 'once_daily';
  final List<ReminderTime> _times = [ReminderTime(hour: 8, minute: 0)];
  final _service = MedicationReminderService();
  bool _isSaving = false;

  final _frequencies = [
    ('once_daily', 'Once daily'),
    ('twice_daily', 'Twice daily'),
    ('three_times', '3 times daily'),
    ('four_times', '4 times daily'),
    ('as_needed', 'As needed'),
  ];

  @override
  void initState() {
    super.initState();
    _service.init();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('New Medication Reminder', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(height: 20),

                  _field('Medication Name', _medNameCtrl),
                  const SizedBox(height: 12),
                  _field('Dosage (e.g. 500mg)', _dosageCtrl),
                  const SizedBox(height: 16),

                  const Text('Frequency', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _frequencies.map((f) {
                      final selected = _frequency == f.$1;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _frequency = f.$1;
                            _updateTimeSlots();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.canopy.withOpacity(0.1) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? AppColors.canopy : AppColors.borderSubtle,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Text(f.$2, style: TextStyle(
                            fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected ? AppColors.canopy : Colors.grey.shade700,
                          )),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Time slots
                  Row(
                    children: [
                      const Text('Reminder Times', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const Spacer(),
                      if (_frequency != 'as_needed')
                        TextButton.icon(
                          onPressed: _addTimeSlot,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Time'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._times.asMap().entries.map((entry) {
                    final i = entry.key;
                    final t = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.alarm_outlined, color: AppColors.canopy, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.formatted, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                Text(t.shortLabel, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _pickTime(i),
                            child: const Text('Change'),
                          ),
                          if (_times.length > 1)
                            IconButton(
                              onPressed: () => setState(() => _times.removeAt(i)),
                              icon: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 20),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving || _medNameCtrl.text.trim().isEmpty ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.canopy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Reminder', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateTimeSlots() {
    switch (_frequency) {
      case 'once_daily':
        _times.clear();
        _times.add(ReminderTime(hour: 8, minute: 0));
        break;
      case 'twice_daily':
        _times.clear();
        _times.add(ReminderTime(hour: 8, minute: 0));
        _times.add(ReminderTime(hour: 20, minute: 0));
        break;
      case 'three_times':
        _times.clear();
        _times.add(ReminderTime(hour: 8, minute: 0));
        _times.add(ReminderTime(hour: 14, minute: 0));
        _times.add(ReminderTime(hour: 20, minute: 0));
        break;
      case 'four_times':
        _times.clear();
        _times.add(ReminderTime(hour: 8, minute: 0));
        _times.add(ReminderTime(hour: 12, minute: 0));
        _times.add(ReminderTime(hour: 17, minute: 0));
        _times.add(ReminderTime(hour: 22, minute: 0));
        break;
      case 'as_needed':
        _times.clear();
        _times.add(ReminderTime(hour: 8, minute: 0, label: 'As needed'));
        break;
    }
  }

  void _addTimeSlot() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked != null) {
      setState(() => _times.add(ReminderTime(hour: picked.hour, minute: picked.minute)));
    }
  }

  void _pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _times[index].hour, minute: _times[index].minute),
    );
    if (picked != null) {
      setState(() {
        _times[index] = ReminderTime(hour: picked.hour, minute: picked.minute);
      });
    }
  }

  Widget _field(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.canopy, width: 1.5),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final patientId = _supabase.auth.currentUser?.id;
    if (patientId == null) return;

    setState(() => _isSaving = true);

    // Request permission first
    await _service.requestPermission();

    final result = await _service.saveReminder(
      patientId: patientId,
      medicationName: _medNameCtrl.text.trim(),
      dosage: _dosageCtrl.text.trim(),
      frequency: _frequency,
      times: _times,
    );

    if (mounted) {
      Navigator.pop(context);
      widget.onComplete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result != null ? 'Reminder saved' : 'Failed to save'),
          backgroundColor: result != null ? const Color(0xFF2E7D32) : Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _medNameCtrl.dispose();
    _dosageCtrl.dispose();
    super.dispose();
  }
}
