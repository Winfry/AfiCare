/// One row from the local `kmpdc_practitioners` mirror of KMPDC's public
/// register (029_kmpdc_practitioners.sql) -- see sync-kmpdc-register for
/// how it's populated. `maskedRegistrationNo` is exactly what KMPDC
/// publishes (e.g. "E0****2") -- they never expose full registration
/// numbers publicly, so this can only ever support a pattern match
/// against a full number the caller already has on file, never an exact
/// lookup by ID alone. For the `medical_intern`/`dental_intern` cadres
/// (031_provisional_provider_verification.sql) this is always null --
/// confirmed by fetching KMPDC's actual intern register pages directly:
/// they publish no registration number at all for interns, only name/
/// address/cadre/course. Verifying an intern can only ever be a name
/// match, not an ID pattern match.
class KmpdcPractitionerModel {
  final String id;
  final String cadre;
  final String fullName;
  final String? maskedRegistrationNo;
  final String? qualifications;
  final String? discipline;
  final String? licenseType;
  final String? status;
  final DateTime syncedAt;

  KmpdcPractitionerModel({
    required this.id,
    required this.cadre,
    required this.fullName,
    this.maskedRegistrationNo,
    this.qualifications,
    this.discipline,
    this.licenseType,
    this.status,
    required this.syncedAt,
  });

  factory KmpdcPractitionerModel.fromJson(Map<String, dynamic> json) {
    return KmpdcPractitionerModel(
      id: json['id'] as String,
      cadre: json['cadre'] as String,
      fullName: json['full_name'] as String,
      maskedRegistrationNo: json['masked_registration_no'] as String?,
      qualifications: json['qualifications'] as String?,
      discipline: json['discipline'] as String?,
      licenseType: json['license_type'] as String?,
      status: json['status'] as String?,
      syncedAt: DateTime.parse(json['synced_at'] as String),
    );
  }
}
