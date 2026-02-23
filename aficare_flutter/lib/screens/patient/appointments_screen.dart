import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/appointment_model.dart';
import '../../models/user_model.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final apt = Provider.of<AppointmentProvider>(context, listen: false);
    final uid = auth.currentUser?.id;
    if (uid != null) {
      await apt.loadAppointments(uid);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        backgroundColor: AfiCareTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openBookingSheet,
        backgroundColor: AfiCareTheme.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Book Appointment'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<AppointmentProvider>(
              builder: (context, provider, _) {
                final now = DateTime.now();
                final upcoming = provider.appointments
                    .where((a) =>
                        a.scheduledAt.isAfter(now) &&
                        a.status != AppointmentStatus.cancelled &&
                        a.status != AppointmentStatus.completed)
                    .toList()
                  ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
                final past = provider.appointments
                    .where((a) =>
                        a.scheduledAt.isBefore(now) ||
                        a.status == AppointmentStatus.cancelled ||
                        a.status == AppointmentStatus.completed)
                    .toList()
                  ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

                if (provider.appointments.isEmpty) {
                  return _buildEmptyState();
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (upcoming.isNotEmpty) ...[
                        const Text(
                          'Upcoming',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ...upcoming.map((a) => _buildAppointmentCard(a)),
                        const SizedBox(height: 20),
                      ],
                      if (past.isNotEmpty)
                        ExpansionTile(
                          title: Text(
                            'Past Appointments (${past.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          leading: const Icon(Icons.history),
                          children: past
                              .map((a) =>
                                  _buildAppointmentCard(a, greyed: true))
                              .toList(),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No appointments yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Book Appointment" below to schedule your first visit.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(AppointmentModel a, {bool greyed = false}) {
    final textColor = greyed ? Colors.grey[600]! : Colors.black87;
    final canCancel = !greyed &&
        (a.status == AppointmentStatus.pending ||
            a.status == AppointmentStatus.confirmed);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  a.type == AppointmentType.telehealth
                      ? Icons.video_call
                      : Icons.local_hospital,
                  color: greyed ? Colors.grey : AfiCareTheme.primaryGreen,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _formatDateTime(a.scheduledAt),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                _buildStatusBadge(a.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildTypeBadge(a.type),
                const SizedBox(width: 8),
                if (a.isFollowUp)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Follow-up',
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ),
              ],
            ),
            if (a.chiefComplaint != null &&
                a.chiefComplaint!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                a.chiefComplaint!,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (canCancel) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _cancelAppointment(a),
                  icon: const Icon(Icons.cancel_outlined,
                      size: 16, color: Colors.red),
                  label: const Text('Cancel',
                      style: TextStyle(color: Colors.red)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(AppointmentStatus status) {
    Color color;
    String label;
    switch (status) {
      case AppointmentStatus.pending:
        color = Colors.orange;
        label = 'Pending';
        break;
      case AppointmentStatus.confirmed:
        color = Colors.green;
        label = 'Confirmed';
        break;
      case AppointmentStatus.completed:
        color = Colors.grey;
        label = 'Completed';
        break;
      case AppointmentStatus.cancelled:
        color = Colors.red;
        label = 'Cancelled';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTypeBadge(AppointmentType type) {
    final isRemote = type == AppointmentType.telehealth;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color:
            (isRemote ? Colors.purple : Colors.teal).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRemote ? Icons.video_call : Icons.location_on,
            size: 12,
            color: isRemote ? Colors.purple : Colors.teal,
          ),
          const SizedBox(width: 3),
          Text(
            isRemote ? 'Telehealth' : 'In-Person',
            style: TextStyle(
              fontSize: 11,
              color: isRemote ? Colors.purple : Colors.teal,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} at $hour:$min $amPm';
  }

  Future<void> _cancelAppointment(AppointmentModel a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: Text(
            'Cancel the appointment on ${_formatDateTime(a.scheduledAt)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Cancel',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final provider =
        Provider.of<AppointmentProvider>(context, listen: false);
    final ok = await provider.updateStatus(a.id, AppointmentStatus.cancelled);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Appointment cancelled' : 'Could not cancel — try again'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
    }
  }

  // ── Booking bottom sheet ──────────────────────────────────

  void _openBookingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BookingSheet(
        onBooked: () {
          _load();
        },
      ),
    );
  }
}

// ── Booking sheet as a separate StatefulWidget ──────────────

class _BookingSheet extends StatefulWidget {
  final VoidCallback onBooked;

  const _BookingSheet({required this.onBooked});

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  List<UserModel> _providers = [];
  UserModel? _selectedProvider;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  AppointmentType _type = AppointmentType.inPerson;
  final _complaintController = TextEditingController();
  bool _isSubmitting = false;
  bool _loadingProviders = true;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  void dispose() {
    _complaintController.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select()
          .inFilter('role', ['doctor', 'nurse']);
      if (mounted) {
        setState(() {
          _providers = (response as List)
              .map((j) => UserModel.fromJson(j))
              .toList();
          _loadingProviders = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProviders = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedProvider == null ||
        _selectedDate == null ||
        _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please select a provider, date, and time.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final patientId = auth.currentUser?.id ?? '';

    final scheduledAt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final appointment = AppointmentModel(
      id: '',
      patientId: patientId,
      providerId: _selectedProvider!.id,
      scheduledAt: scheduledAt,
      type: _type,
      status: AppointmentStatus.pending,
      chiefComplaint: _complaintController.text.trim().isEmpty
          ? null
          : _complaintController.text.trim(),
      isFollowUp: false,
    );

    final provider =
        Provider.of<AppointmentProvider>(context, listen: false);
    final ok = await provider.bookAppointment(appointment);

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Appointment booked successfully!'
            : 'Could not book — try again'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) widget.onBooked();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Book Appointment',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Provider picker
            const Text('Provider',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _loadingProviders
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<UserModel>(
                    value: _selectedProvider,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Select provider',
                    ),
                    items: _providers
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                  '${p.fullName} (${p.role.name})'),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedProvider = v),
                  ),
            const SizedBox(height: 16),

            // Date picker
            const Text('Date',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      DateTime.now().add(const Duration(days: 1)),
                  firstDate:
                      DateTime.now().add(const Duration(days: 1)),
                  lastDate:
                      DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : 'Select date',
                  style: TextStyle(
                    color: _selectedDate != null
                        ? Colors.black87
                        : Colors.grey[500],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Time picker
            const Text('Time',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (picked != null) {
                  setState(() => _selectedTime = picked);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.access_time),
                ),
                child: Text(
                  _selectedTime != null
                      ? _selectedTime!.format(context)
                      : 'Select time',
                  style: TextStyle(
                    color: _selectedTime != null
                        ? Colors.black87
                        : Colors.grey[500],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Type toggle
            const Text('Appointment Type',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<AppointmentType>(
              segments: const [
                ButtonSegment(
                  value: AppointmentType.inPerson,
                  icon: Icon(Icons.location_on),
                  label: Text('In-Person'),
                ),
                ButtonSegment(
                  value: AppointmentType.telehealth,
                  icon: Icon(Icons.video_call),
                  label: Text('Telehealth'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) =>
                  setState(() => _type = s.first),
              style: ButtonStyle(
                backgroundColor:
                    WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AfiCareTheme.primaryGreen;
                  }
                  return null;
                }),
                foregroundColor:
                    WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return null;
                }),
              ),
            ),
            const SizedBox(height: 16),

            // Chief complaint
            const Text('Chief Complaint (Optional)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _complaintController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'What will you be seen for?',
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white))
                    : const Icon(Icons.check),
                label:
                    Text(_isSubmitting ? 'Booking…' : 'Book Appointment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AfiCareTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
