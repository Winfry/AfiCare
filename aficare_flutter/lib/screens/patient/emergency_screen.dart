import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/active_patient.dart';
import '../../providers/patient_profile_provider.dart';
import '../../services/offline_cache.dart';
import '../../theme/patient_tokens.dart';
import 'widgets/patient_ui.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final _supabase = Supabase.instance.client;

  /// The `emergency_profiles` row as loaded, or null when none exists yet.
  Map<String, dynamic>? _profile;
  _EmergencyDetails _details = const _EmergencyDetails();
  bool _isLoading = true;
  bool _loadFailed = false;
  DateTime? _fromCacheAt;

  /// Whose emergency details are loaded, so switching profile while this
  /// screen is open reloads rather than leaving the previous person's
  /// blood type on screen.
  String? _loadedFor;

  ActivePatient get _subject => ActivePatient.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final subject = _subject;
    if (subject.id.isNotEmpty && subject.id != _loadedFor) {
      _loadedFor = subject.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadProfile();
      });
    }
  }

  Future<void> _loadProfile() async {
    // The active profile, not the account holder: a child's blood type
    // and allergies are precisely what this screen exists to show, and
    // showing the parent's here could inform the wrong treatment.
    final patientId = ActivePatient.of(context, listen: false).id;
    if (patientId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final data = await _supabase
          .from('emergency_profiles')
          .select()
          .eq('patient_id', patientId)
          .maybeSingle();

      if (data != null) {
        // Of everything in the app this is the most important thing to
        // have on the device: blood type and allergies are needed exactly
        // when there is no time and often no signal.
        await OfflineCache.save(OfflineCache.emergencyKey(patientId), data);
      }
      if (mounted) setState(() => _applyProfile(data, fromCacheAt: null));
    } catch (e) {
      debugPrint('Error loading emergency profile: $e');
      // Fall back to the saved copy instead of presenting empty fields —
      // a blank blood type here is not a neutral default.
      final cached = OfflineCache.read(OfflineCache.emergencyKey(patientId));
      final payload = cached?.payload;
      if (payload is Map && mounted) {
        setState(() => _applyProfile(
              Map<String, dynamic>.from(payload),
              fromCacheAt: cached!.savedAt,
            ));
      } else if (mounted) {
        setState(() => _loadFailed = true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Caller is responsible for being inside setState.
  void _applyProfile(Map<String, dynamic>? data, {required DateTime? fromCacheAt}) {
    _profile = data;
    _fromCacheAt = fromCacheAt;
    _loadFailed = false;
    _details = data == null ? const _EmergencyDetails() : _EmergencyDetails.fromRow(data);
  }

  /// What the page shows. Where this person's emergency details have no
  /// blood type or allergies yet, their main profile's are used instead:
  /// "none on file" beside a profile that lists penicillin is the one
  /// answer this screen must never give.
  _EmergencyDetails _shown(ActivePatient subject) => _details.copyWith(
        bloodType: _details.bloodType ?? subject.bloodType,
        allergies: _details.allergies.isNotEmpty ? _details.allergies : (subject.allergies ?? const []),
      );

  List<String> _conditions(ActivePatient subject) {
    final own = (_profile?['chronic_conditions'] as List?)?.cast<String>() ?? const <String>[];
    if (own.isNotEmpty || subject.isDependent) return own;
    return context.watch<PatientProfileProvider>().profile?.chronicConditions ?? const [];
  }

  /// Returns null on success, or what to tell the person on failure, so
  /// the form can stay open with their edits intact.
  Future<String?> _save(_EmergencyDetails d) async {
    // Saves against whoever is on screen, matching what was loaded —
    // otherwise editing a child's details would overwrite the parent's.
    final patientId = ActivePatient.of(context, listen: false).id;
    if (patientId.isEmpty) return 'No profile is selected.';

    final row = d.toRow(patientId);
    final existingId = _profile?['id'];
    if (existingId != null) row['id'] = existingId;

    try {
      // .select() so a write that row-level security quietly drops
      // comes back empty instead of looking like a success.
      final saved = await _supabase.from('emergency_profiles').upsert(row).select().maybeSingle();
      if (saved == null) {
        return "These details weren't saved. Your account may not be allowed to change them.";
      }
      await OfflineCache.save(OfflineCache.emergencyKey(patientId), saved);
      if (mounted) setState(() => _applyProfile(saved, fromCacheAt: null));
      return null;
    } catch (e) {
      debugPrint('Error saving emergency profile: $e');
      return "Couldn't save. Check your connection and try again.";
    }
  }

  Future<void> _edit(_EmergencyDetails shown) async {
    final saved = await showPModal<bool>(
      context: context,
      title: 'Emergency details',
      builder: (ctx) => _EmergencyForm(initial: shown, onSave: _save),
    );
    if (saved == true && mounted) pToast(context, 'Emergency details saved');
  }

  Future<void> _call(String number) async {
    final dialable = number.replaceAll(RegExp(r'[^\d+]'), '');
    try {
      if (await launchUrl(Uri(scheme: 'tel', path: dialable))) return;
    } catch (e) {
      debugPrint('Could not start call: $e');
    }
    if (mounted) pToast(context, "Couldn't start a call here. Dial $number from your phone.");
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const PLoadingPage();

    final subject = _subject;
    final shown = _shown(subject);
    final whose = subject.isDependent ? "${subject.firstName}'s" : 'your';

    return PSliverPage(
      eyebrow: 'When minutes matter',
      title: subject.isDependent ? "${subject.firstName}'s emergency profile" : 'Emergency support',
      subtitle: subject.isDependent
          ? 'The things a stranger would need to know about ${subject.firstName}, ready in one tap.'
          : 'The things a stranger would need to know about you, ready in one tap.',
      action: _loadFailed
          ? null
          : PButton('Edit details', kind: PButtonKind.alt, icon: Icons.edit_outlined, onPressed: () => _edit(shown)),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Says plainly when the details below are the saved copy,
              // so nobody acts on them believing they're current.
              if (_fromCacheAt != null) ...[
                POfflineBanner(savedAt: _fromCacheAt!, onRetry: _loadProfile),
                const SizedBox(height: 16),
              ],
              if (_loadFailed) ...[
                PLoadError(what: '$whose emergency details', onRetry: _loadProfile),
                const SizedBox(height: 29),
              ] else ...[
                _FactsRow(
                  bloodType: shown.bloodType,
                  conditions: _conditions(subject),
                  allergies: shown.allergies,
                ),
                const SizedBox(height: 29),
                const PHeading('Who to call'),
                _ContactsCard(details: shown, onCall: _call, onAdd: () => _edit(shown)),
                const SizedBox(height: 29),
              ],
              // Shown even when the details failed to load: dialling 999
              // must never depend on the network.
              const PHeading("If it's urgent"),
              _UrgentCard(onCall: () => _call('999')),
              if (!_loadFailed && shown.notes.isNotEmpty) ...[
                const SizedBox(height: 29),
                const PHeading('Notes for responders'),
                PCard(child: Text(shown.notes, style: PT.body())),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Data
// ═══════════════════════════════════════════════════════════════════════

/// The editable part of an `emergency_profiles` row.
@immutable
class _EmergencyDetails {
  const _EmergencyDetails({
    this.bloodType,
    this.allergies = const [],
    this.contactName = '',
    this.contactPhone = '',
    this.contactRelationship = '',
    this.contact2Name = '',
    this.contact2Phone = '',
    this.contact2Relationship = '',
    this.notes = '',
  });

  factory _EmergencyDetails.fromRow(Map<String, dynamic> row) => _EmergencyDetails(
        bloodType: row['blood_type'] as String?,
        allergies: (row['allergies'] as List?)?.cast<String>() ?? const [],
        contactName: row['emergency_contact_name'] as String? ?? '',
        contactPhone: row['emergency_contact_phone'] as String? ?? '',
        contactRelationship: row['emergency_contact_relationship'] as String? ?? '',
        contact2Name: row['emergency_contact2_name'] as String? ?? '',
        contact2Phone: row['emergency_contact2_phone'] as String? ?? '',
        contact2Relationship: row['emergency_contact2_relationship'] as String? ?? '',
        notes: row['notes'] as String? ?? '',
      );

  final String? bloodType;
  final List<String> allergies;
  final String contactName;
  final String contactPhone;
  final String contactRelationship;
  final String contact2Name;
  final String contact2Phone;
  final String contact2Relationship;
  final String notes;

  _EmergencyDetails copyWith({String? bloodType, List<String>? allergies}) => _EmergencyDetails(
        bloodType: bloodType ?? this.bloodType,
        allergies: allergies ?? this.allergies,
        contactName: contactName,
        contactPhone: contactPhone,
        contactRelationship: contactRelationship,
        contact2Name: contact2Name,
        contact2Phone: contact2Phone,
        contact2Relationship: contact2Relationship,
        notes: notes,
      );

  Map<String, dynamic> toRow(String patientId) {
    String? orNull(String s) => s.trim().isEmpty ? null : s.trim();
    return {
      'patient_id': patientId,
      'blood_type': bloodType,
      'allergies': allergies,
      'emergency_contact_name': contactName.trim(),
      'emergency_contact_phone': contactPhone.trim(),
      'emergency_contact_relationship': contactRelationship.trim(),
      'emergency_contact2_name': orNull(contact2Name),
      'emergency_contact2_phone': orNull(contact2Phone),
      'emergency_contact2_relationship': orNull(contact2Relationship),
      'notes': orNull(notes),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Facts — blood type, conditions, allergies (`.grid3` of `.card`)
// ═══════════════════════════════════════════════════════════════════════

class _FactsRow extends StatelessWidget {
  const _FactsRow({required this.bloodType, required this.conditions, required this.allergies});

  final String? bloodType;
  final List<String> conditions;
  final List<String> allergies;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _Fact(label: 'Blood type', value: bloodType ?? 'Not set', large: bloodType != null),
      _Fact(
        label: 'Conditions',
        value: conditions.isEmpty ? 'None listed' : conditions.join(', '),
      ),
      _Fact(
        label: 'Allergies',
        value: allergies.isEmpty ? 'None on file' : '${allergies.length} on file',
        // The count alone is no use to a responder; the names are the point.
        below: allergies.isEmpty
            ? null
            : Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final a in allergies) PBadge(a, tone: PTone.red)],
              ),
      ),
    ];

    if (PT.isMobile(context)) {
      return Column(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: 14),
          ],
        ],
      );
    }
    // Equal heights, as in the spec's grid; PGrid top-aligns instead.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            Expanded(child: cards[i]),
            if (i < cards.length - 1) const SizedBox(width: 14),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.large = false, this.below});

  final String label;
  final String value;
  final bool large;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    return PCard(
      padding: const EdgeInsets.all(21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: PT.label()),
          const SizedBox(height: 12),
          Text(value, style: PT.metric().copyWith(fontSize: large ? 38 : 24, height: 1.1)),
          if (below != null) ...[const SizedBox(height: 12), below!],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Who to call
// ═══════════════════════════════════════════════════════════════════════

class _ContactsCard extends StatelessWidget {
  const _ContactsCard({required this.details, required this.onCall, required this.onAdd});

  final _EmergencyDetails details;
  final ValueChanged<String> onCall;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final contacts = [
      (details.contactName, details.contactPhone, details.contactRelationship),
      (details.contact2Name, details.contact2Phone, details.contact2Relationship),
    ].where((c) => c.$1.trim().isNotEmpty || c.$2.trim().isNotEmpty).toList();

    return PCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          if (contacts.isEmpty)
            PRow(
              leading: const PSoftIcon(Icons.person_add_alt_1_outlined),
              title: 'No one added yet',
              subtitle: 'Add someone responders can call, like a family member.',
              trailing: [PButton('Add', kind: PButtonKind.alt, dense: true, onPressed: onAdd)],
            ),
          for (int i = 0; i < contacts.length; i++)
            PRow(
              leading: PSoftIcon(i == 0 ? Icons.favorite_border_rounded : Icons.person_outline_rounded),
              title: contacts[i].$1.trim().isEmpty ? 'Unnamed contact' : contacts[i].$1.trim(),
              subtitle: [contacts[i].$3.trim(), contacts[i].$2.trim()].where((s) => s.isNotEmpty).join(' · '),
              trailing: [
                if (i == 0) const PBadge('Primary', tone: PTone.blue),
                if (contacts[i].$2.trim().isNotEmpty)
                  PButton(
                    'Call',
                    kind: PButtonKind.alt,
                    dense: true,
                    icon: Icons.call_outlined,
                    onPressed: () => onCall(contacts[i].$2.trim()),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// If it's urgent
// ═══════════════════════════════════════════════════════════════════════

class _UrgentCard extends StatelessWidget {
  const _UrgentCard({required this.onCall});

  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Call 999 first.', style: PT.rowTitle().copyWith(fontSize: 15)),
        const SizedBox(height: 3),
        Text(
          '112 works too, from any phone. When help arrives, show them this page.',
          style: PT.sub().copyWith(fontSize: 13),
        ),
      ],
    );
    final button = PButton('Call 999', icon: Icons.call_rounded, onPressed: onCall);

    return PCard(
      padding: const EdgeInsets.all(21),
      child: PT.isMobile(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const PSoftIcon(Icons.priority_high_rounded),
                    const SizedBox(width: 15),
                    Expanded(child: text),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(width: double.infinity, child: button),
              ],
            )
          : Row(
              children: [
                const PSoftIcon(Icons.priority_high_rounded),
                const SizedBox(width: 15),
                Expanded(child: text),
                const SizedBox(width: 15),
                button,
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Edit form (inside showPModal)
// ═══════════════════════════════════════════════════════════════════════

class _EmergencyForm extends StatefulWidget {
  const _EmergencyForm({required this.initial, required this.onSave});

  final _EmergencyDetails initial;
  final Future<String?> Function(_EmergencyDetails) onSave;

  @override
  State<_EmergencyForm> createState() => _EmergencyFormState();
}

class _EmergencyFormState extends State<_EmergencyForm> {
  static const _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  late String? _bloodType = widget.initial.bloodType;
  late final List<String> _allergies = List.of(widget.initial.allergies);
  final _allergyCtrl = TextEditingController();
  late final _name = TextEditingController(text: widget.initial.contactName);
  late final _phone = TextEditingController(text: widget.initial.contactPhone);
  late final _rel = TextEditingController(text: widget.initial.contactRelationship);
  late final _name2 = TextEditingController(text: widget.initial.contact2Name);
  late final _phone2 = TextEditingController(text: widget.initial.contact2Phone);
  late final _rel2 = TextEditingController(text: widget.initial.contact2Relationship);
  late final _notes = TextEditingController(text: widget.initial.notes);

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_allergyCtrl, _name, _phone, _rel, _name2, _phone2, _rel2, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addAllergy() {
    final a = _allergyCtrl.text.trim();
    if (a.isEmpty) return;
    setState(() {
      if (!_allergies.any((x) => x.toLowerCase() == a.toLowerCase())) _allergies.add(a);
      _allergyCtrl.clear();
    });
  }

  /// A name with no number (or the reverse) can't be called by anyone.
  String? _checkContact(String which, TextEditingController name, TextEditingController phone) {
    final hasName = name.text.trim().isNotEmpty;
    final hasPhone = phone.text.trim().isNotEmpty;
    if (hasName && !hasPhone) return 'Add a phone number for ${name.text.trim()}.';
    if (hasPhone && !hasName) return 'Add a name for the $which contact.';
    return null;
  }

  Future<void> _save() async {
    // An allergy typed but not added is still meant to be kept.
    _addAllergy();
    final problem = _checkContact('first', _name, _phone) ?? _checkContact('second', _name2, _phone2);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSave(_EmergencyDetails(
      bloodType: _bloodType,
      allergies: _allergies,
      contactName: _name.text,
      contactPhone: _phone.text,
      contactRelationship: _rel.text,
      contact2Name: _name2.text,
      contact2Phone: _phone2.text,
      contact2Relationship: _rel2.text,
      notes: _notes.text,
    ));
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  Widget _text(TextEditingController c, String hint, {TextInputType? keyboard}) =>
      TextField(controller: c, keyboardType: keyboard, decoration: pInput(hint: hint));

  Widget _group(String title) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(title, style: PT.h3().copyWith(fontSize: 15)),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Keep these short and current. Anyone helping in an emergency may read them.',
          style: PT.sub(),
        ),
        _group('Blood type'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final bt in _bloodTypes)
              PChoicePill(
                label: bt,
                selected: _bloodType == bt,
                // Tapping the chosen one again clears it, for "not sure".
                onTap: () => setState(() => _bloodType = _bloodType == bt ? null : bt),
                width: 68,
              ),
          ],
        ),
        _group('Allergies'),
        if (_allergies.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final a in _allergies)
                PRemovableBadge(a, tone: PTone.red, onRemove: () => setState(() => _allergies.remove(a))),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _allergyCtrl,
                decoration: pInput(hint: 'Add an allergy, e.g. Penicillin'),
                onSubmitted: (_) => _addAllergy(),
              ),
            ),
            const SizedBox(width: 8),
            PButton('Add', kind: PButtonKind.alt, onPressed: _addAllergy),
          ],
        ),
        _group('First contact'),
        PFormGrid([
          PField(label: 'Name', child: _text(_name, 'e.g. Mary Achieng')),
          PField(label: 'Phone', child: _text(_phone, '+254 7…', keyboard: TextInputType.phone)),
          PField(label: 'Relationship', child: _text(_rel, 'e.g. Sister')),
        ]),
        _group('Second contact (optional)'),
        PFormGrid([
          PField(label: 'Name', child: _text(_name2, 'Name')),
          PField(label: 'Phone', child: _text(_phone2, '+254 7…', keyboard: TextInputType.phone)),
          PField(label: 'Relationship', child: _text(_rel2, 'Relationship')),
        ]),
        _group('Notes for responders'),
        TextField(
          controller: _notes,
          maxLines: 3,
          decoration: pInput(hint: 'Medical conditions, religious preferences for treatment, etc.'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          PCallout(tone: PTone.red, body: _error!),
        ],
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: PButton(_saving ? 'Saving…' : 'Save', onPressed: _saving ? null : _save),
        ),
      ],
    );
  }
}
