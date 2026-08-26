import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class EmergencyProfile {
  final String id;
  final String patientId;
  final String? bloodType;
  final List<String> allergies;
  final List<String> chronicConditions;
  final List<String> currentMedications;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? emergencyContactRelationship;
  final String? emergencyContact2Name;
  final String? emergencyContact2Phone;
  final String? emergencyContact2Relationship;
  final String? notes;

  EmergencyProfile({
    required this.id,
    required this.patientId,
    this.bloodType,
    this.allergies = const [],
    this.chronicConditions = const [],
    this.currentMedications = const [],
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emergencyContactRelationship,
    this.emergencyContact2Name,
    this.emergencyContact2Phone,
    this.emergencyContact2Relationship,
    this.notes,
  });

  factory EmergencyProfile.fromJson(Map<String, dynamic> json) {
    return EmergencyProfile(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      bloodType: json['blood_type'] as String?,
      allergies: json['allergies'] != null
          ? List<String>.from(json['allergies'] as List)
          : <String>[],
      chronicConditions: json['chronic_conditions'] != null
          ? List<String>.from(json['chronic_conditions'] as List)
          : <String>[],
      currentMedications: json['current_medications'] != null
          ? List<String>.from(json['current_medications'] as List)
          : <String>[],
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
      emergencyContactRelationship: json['emergency_contact_relationship'] as String?,
      emergencyContact2Name: json['emergency_contact2_name'] as String?,
      emergencyContact2Phone: json['emergency_contact2_phone'] as String?,
      emergencyContact2Relationship: json['emergency_contact2_relationship'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'blood_type': bloodType,
      'allergies': allergies,
      'chronic_conditions': chronicConditions,
      'current_medications': currentMedications,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
      'emergency_contact_relationship': emergencyContactRelationship,
      'emergency_contact2_name': emergencyContact2Name,
      'emergency_contact2_phone': emergencyContact2Phone,
      'emergency_contact2_relationship': emergencyContact2Relationship,
      'notes': notes,
    };
  }
}

class EmergencyProfileProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  EmergencyProfile? _profile;
  bool _isLoading = false;
  String? _error;

  EmergencyProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get isComplete {
    if (_profile == null) return false;
    return _profile!.bloodType != null &&
        _profile!.allergies.isNotEmpty &&
        _profile!.emergencyContactName != null &&
        _profile!.emergencyContactPhone != null;
  }

  Future<void> loadProfile(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _supabase
          .from('emergency_profiles')
          .select()
          .eq('patient_id', patientId)
          .maybeSingle();
      if (data != null) {
        _profile = EmergencyProfile.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error loading emergency profile: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> saveProfile({
    required String patientId,
    String? bloodType,
    List<String>? allergies,
    List<String>? chronicConditions,
    List<String>? currentMedications,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelationship,
    String? emergencyContact2Name,
    String? emergencyContact2Phone,
    String? emergencyContact2Relationship,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final existing = _profile;
      final profileData = EmergencyProfile(
        id: existing?.id ?? const Uuid().v4(),
        patientId: patientId,
        bloodType: bloodType ?? existing?.bloodType,
        allergies: allergies ?? existing?.allergies ?? [],
        chronicConditions: chronicConditions ?? existing?.chronicConditions ?? [],
        currentMedications: currentMedications ?? existing?.currentMedications ?? [],
        emergencyContactName: emergencyContactName ?? existing?.emergencyContactName,
        emergencyContactPhone: emergencyContactPhone ?? existing?.emergencyContactPhone,
        emergencyContactRelationship: emergencyContactRelationship ?? existing?.emergencyContactRelationship,
        emergencyContact2Name: emergencyContact2Name ?? existing?.emergencyContact2Name,
        emergencyContact2Phone: emergencyContact2Phone ?? existing?.emergencyContact2Phone,
        emergencyContact2Relationship: emergencyContact2Relationship ?? existing?.emergencyContact2Relationship,
        notes: notes ?? existing?.notes,
      );

      await _supabase.from('emergency_profiles').upsert(profileData.toJson());
      _profile = profileData;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
