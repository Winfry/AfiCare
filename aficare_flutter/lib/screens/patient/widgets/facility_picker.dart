import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/patient_tokens.dart';
import 'patient_ui.dart';

/// A facility as the patient picks it: who and where.
class FacilityChoice {
  const FacilityChoice({required this.id, required this.name, this.place});

  final String id;
  final String name;

  /// "Kisumu · Sub-county hospital", when known.
  final String? place;

  factory FacilityChoice.fromJson(Map<String, dynamic> json) {
    String? clean(Object? v) {
      final s = (v as String?)?.trim();
      return s == null || s.isEmpty ? null : s;
    }

    final where = clean(json['sub_county']) ?? clean(json['county']);
    final county = clean(json['county']);
    final type = clean(json['type'])?.replaceAll('_', ' ');
    final parts = <String>[
      if (where != null) where,
      if (county != null && county != where) county,
      if (type != null) '${type[0].toUpperCase()}${type.substring(1)}',
    ];
    final name = clean(json['name']) ?? 'Facility';
    return FacilityChoice(id: json['id'] as String, name: name, place: parts.isEmpty ? null : parts.join(' · '));
  }
}

/// Finds facilities by name or place. There are over ten thousand, so
/// they are searched, never listed in full.
class FacilitySearchService {
  FacilitySearchService([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const maxResults = 25;
  static const _columns = 'id, name, type, county, sub_county';

  /// Facilities whose name, county or sub-county contains [query].
  /// Throws when the search could not be done.
  Future<List<FacilityChoice>> search(String query) async {
    final q = clean(query);
    if (q.length < 2) return const [];
    final rows = await _client
        .from('facilities')
        .select(_columns)
        // Quoted, so names with full stops, commas or apostrophes
        // ("St. Mary's") are searched as typed.
        .or('name.ilike."*$q*",county.ilike."*$q*",sub_county.ilike."*$q*"')
        .order('name')
        .limit(maxResults);
    return [for (final r in rows as List) FacilityChoice.fromJson(Map<String, dynamic>.from(r as Map))];
  }

  /// The facility with [id], or null if there is none.
  Future<FacilityChoice?> byId(String id) async {
    final row = await _client.from('facilities').select(_columns).eq('id', id).maybeSingle();
    return row == null ? null : FacilityChoice.fromJson(row);
  }

  /// What she typed, without the few characters that would break the
  /// quoted search (quotes, backslashes, wildcards), spaces tidied.
  static String clean(String query) =>
      query.replaceAll(RegExp(r'["\\*%]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Search-as-you-type facility picker. Shows the chosen facility with a
/// Change button, or a search box with matching facilities to tap.
class FacilityPicker extends StatefulWidget {
  const FacilityPicker({super.key, required this.selected, required this.onChanged, this.service});

  final FacilityChoice? selected;
  final ValueChanged<FacilityChoice> onChanged;

  /// For tests.
  final FacilitySearchService? service;

  @override
  State<FacilityPicker> createState() => _FacilityPickerState();
}

enum _SearchState { idle, searching, failed, done }

class _FacilityPickerState extends State<FacilityPicker> {
  late final FacilitySearchService _service = widget.service ?? FacilitySearchService();
  final _query = TextEditingController();
  Timer? _debounce;
  bool _changing = false;
  _SearchState _state = _SearchState.idle;
  List<FacilityChoice> _results = const [];

  /// Only the newest search's answer is shown.
  int _searchNo = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onTyped(String _) {
    _debounce?.cancel();
    if (FacilitySearchService.clean(_query.text).length < 2) {
      _searchNo++;
      setState(() {
        _state = _SearchState.idle;
        _results = const [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    final no = ++_searchNo;
    setState(() => _state = _SearchState.searching);
    try {
      final found = await _service.search(_query.text);
      if (!mounted || no != _searchNo) return;
      setState(() {
        _results = found;
        _state = _SearchState.done;
      });
    } catch (e) {
      debugPrint('Facility search failed: $e');
      if (!mounted || no != _searchNo) return;
      setState(() => _state = _SearchState.failed);
    }
  }

  void _pick(FacilityChoice f) {
    _debounce?.cancel();
    _searchNo++;
    setState(() {
      _changing = false;
      _query.clear();
      _results = const [];
      _state = _SearchState.idle;
    });
    widget.onChanged(f);
  }

  @override
  Widget build(BuildContext context) {
    final chosen = widget.selected;
    if (chosen != null && !_changing) {
      return PRow(
        leading: const PSoftIcon(Icons.local_hospital_outlined, size: 38),
        title: chosen.name,
        subtitle: chosen.place ?? 'Your home facility',
        trailing: [
          PButton('Change', kind: PButtonKind.alt, dense: true, onPressed: () => setState(() => _changing = true)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _query,
          onChanged: _onTyped,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) {
            if (FacilitySearchService.clean(_query.text).length >= 2) {
              _debounce?.cancel();
              _search();
            }
          },
          decoration: pInput(hint: 'Search by name or town, e.g. Tamia or Kisumu').copyWith(
            prefixIcon: const Icon(Icons.search, size: 18, color: PT.muted),
          ),
        ),
        const SizedBox(height: 10),
        ..._below(),
        if (chosen != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _changing = false),
              child: Text('Keep ${chosen.name}', style: PT.body().copyWith(color: PT.teal)),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _below() {
    switch (_state) {
      case _SearchState.idle:
        return [Text('Type at least 2 letters of its name or town.', style: PT.rowSub())];
      case _SearchState.searching:
        return const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: PT.teal))),
          ),
        ];
      case _SearchState.failed:
        return [
          PCallout(
            tone: PTone.warn,
            body: "We couldn't search facilities just now. Check your connection.",
            trailing: PButton('Try again', kind: PButtonKind.alt, dense: true, onPressed: _search),
          ),
        ];
      case _SearchState.done:
        if (_results.isEmpty) {
          return [
            Text(
              'No facility matches "${FacilitySearchService.clean(_query.text)}". '
              'Check the spelling, try the town instead, or skip this for now.',
              style: PT.rowSub(),
            ),
          ];
        }
        return [
          for (final f in _results)
            PRow(
              leading: const PSoftIcon(Icons.local_hospital_outlined, size: 38),
              title: f.name,
              subtitle: f.place ?? '',
              trailing: const [Icon(Icons.chevron_right, size: 18, color: PT.muted)],
              onTap: () => _pick(f),
            ),
          if (_results.length >= FacilitySearchService.maxResults)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Showing the first ${FacilitySearchService.maxResults}. Type more to narrow it down.',
                  style: PT.rowSub()),
            ),
        ];
    }
  }
}
