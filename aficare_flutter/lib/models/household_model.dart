class Household {
  final String id;
  final String chvId;
  final String householdName;
  final String? location;
  final String? village;
  final String? subCounty;
  final String? county;
  final int totalMembers;
  final int childrenUnder5;
  final int pregnantWomen;
  final int elderlyMembers;
  final int chronicallyIll;
  final String? gpsCoordinates;
  final String? waterSource;
  final String? sanitationType;
  final bool hasMosquitoNets;
  final DateTime createdAt;

  Household({
    required this.id,
    required this.chvId,
    required this.householdName,
    this.location,
    this.village,
    this.subCounty,
    this.county,
    this.totalMembers = 0,
    this.childrenUnder5 = 0,
    this.pregnantWomen = 0,
    this.elderlyMembers = 0,
    this.chronicallyIll = 0,
    this.gpsCoordinates,
    this.waterSource,
    this.sanitationType,
    this.hasMosquitoNets = false,
    required this.createdAt,
  });

  factory Household.fromJson(Map<String, dynamic> json) {
    return Household(
      id: json['id'] as String? ?? '',
      chvId: json['chv_id'] as String? ?? '',
      householdName: json['household_name'] as String? ?? '',
      location: json['location'] as String?,
      village: json['village'] as String?,
      subCounty: json['sub_county'] as String?,
      county: json['county'] as String?,
      totalMembers: json['total_members'] as int? ?? 0,
      childrenUnder5: json['children_under_5'] as int? ?? 0,
      pregnantWomen: json['pregnant_women'] as int? ?? 0,
      elderlyMembers: json['elderly_members'] as int? ?? 0,
      chronicallyIll: json['chronically_ill'] as int? ?? 0,
      gpsCoordinates: json['gps_coordinates'] as String?,
      waterSource: json['water_source'] as String?,
      sanitationType: json['sanitation_type'] as String?,
      hasMosquitoNets: json['has_mosquito_nets'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chv_id': chvId,
      'household_name': householdName,
      'location': location,
      'village': village,
      'sub_county': subCounty,
      'county': county,
      'total_members': totalMembers,
      'children_under_5': childrenUnder5,
      'pregnant_women': pregnantWomen,
      'elderly_members': elderlyMembers,
      'chronically_ill': chronicallyIll,
      'gps_coordinates': gpsCoordinates,
      'water_source': waterSource,
      'sanitation_type': sanitationType,
      'has_mosquito_nets': hasMosquitoNets,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class HouseholdMember {
  final String id;
  final String householdId;
  final String? patientId;
  final String name;
  final String? relationship;
  final int? age;
  final String? gender;
  final bool isPregnant;
  final bool isChildUnder5;
  final bool isElderly;
  final List<String> chronicConditions;
  final bool isAlive;
  final DateTime createdAt;

  HouseholdMember({
    required this.id,
    required this.householdId,
    this.patientId,
    required this.name,
    this.relationship,
    this.age,
    this.gender,
    this.isPregnant = false,
    this.isChildUnder5 = false,
    this.isElderly = false,
    this.chronicConditions = const [],
    this.isAlive = true,
    required this.createdAt,
  });

  factory HouseholdMember.fromJson(Map<String, dynamic> json) {
    return HouseholdMember(
      id: json['id'] as String? ?? '',
      householdId: json['household_id'] as String? ?? '',
      patientId: json['patient_id'] as String?,
      name: json['name'] as String? ?? '',
      relationship: json['relationship'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      isPregnant: json['is_pregnant'] as bool? ?? false,
      isChildUnder5: json['is_child_under_5'] as bool? ?? false,
      isElderly: json['is_elderly'] as bool? ?? false,
      chronicConditions: json['chronic_conditions'] != null
          ? List<String>.from(json['chronic_conditions'] as List)
          : <String>[],
      isAlive: json['is_alive'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      'patient_id': patientId,
      'name': name,
      'relationship': relationship,
      'age': age,
      'gender': gender,
      'is_pregnant': isPregnant,
      'is_child_under_5': isChildUnder5,
      'is_elderly': isElderly,
      'chronic_conditions': chronicConditions,
      'is_alive': isAlive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class CommunityScreening {
  final String id;
  final String chvId;
  final String? householdId;
  final String? patientId;
  final String screeningType; // 'malaria', 'tb', 'malnutrition', 'blood_pressure', 'blood_sugar', 'visual'
  final Map<String, dynamic> results;
  final String outcome; // 'normal', 'referral_needed', 'referred'
  final String? referredTo;
  final String? notes;
  final DateTime screeningDate;

  CommunityScreening({
    required this.id,
    required this.chvId,
    this.householdId,
    this.patientId,
    required this.screeningType,
    this.results = const {},
    required this.outcome,
    this.referredTo,
    this.notes,
    required this.screeningDate,
  });

  factory CommunityScreening.fromJson(Map<String, dynamic> json) {
    return CommunityScreening(
      id: json['id'] as String? ?? '',
      chvId: json['chv_id'] as String? ?? '',
      householdId: json['household_id'] as String?,
      patientId: json['patient_id'] as String?,
      screeningType: json['screening_type'] as String? ?? 'malaria',
      results: json['results'] != null
          ? Map<String, dynamic>.from(json['results'] as Map)
          : <String, dynamic>{},
      outcome: json['outcome'] as String? ?? 'normal',
      referredTo: json['referred_to'] as String?,
      notes: json['notes'] as String?,
      screeningDate: json['screening_date'] != null
          ? DateTime.tryParse(json['screening_date'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chv_id': chvId,
      'household_id': householdId,
      'patient_id': patientId,
      'screening_type': screeningType,
      'results': results,
      'outcome': outcome,
      'referred_to': referredTo,
      'notes': notes,
      'screening_date': screeningDate.toIso8601String(),
    };
  }

  static String screeningLabel(String type) {
    switch (type) {
      case 'malaria': return 'Malaria Rapid Diagnostic';
      case 'tb': return 'TB Screening';
      case 'malnutrition': return 'Malnutrition (MUAC)';
      case 'blood_pressure': return 'Blood Pressure';
      case 'blood_sugar': return 'Blood Sugar (RBS)';
      case 'visual': return 'Visual Acuity';
      default: return type;
    }
  }

  static String screeningIcon(String type) {
    switch (type) {
      case 'malaria': return '🦟';
      case 'tb': return '🫁';
      case 'malnutrition': return '📏';
      case 'blood_pressure': return '❤️';
      case 'blood_sugar': return '🩸';
      case 'visual': return '👁️';
      default: return '🔬';
    }
  }
}
