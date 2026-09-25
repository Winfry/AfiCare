/// One live search result from the Nursing Council of Kenya (NCK)'s
/// public register, via the verify-nck-register Edge Function -- see
/// that function for how it's fetched. Deliberately separate from
/// KmpdcPractitionerModel: NCK publishes the FULL, unmasked license
/// number (confirmed by hand against real results, e.g. "594257") --
/// unlike KMPDC, which never exposes a full registration number
/// publicly. Reusing KmpdcPractitionerModel's `maskedRegistrationNo`
/// field for a value that isn't masked would mislabel it.
class NckNurseModel {
  final String fullName;
  final String licenseNumber;
  final String? status;
  final String? validTill;

  NckNurseModel({
    required this.fullName,
    required this.licenseNumber,
    this.status,
    this.validTill,
  });

  factory NckNurseModel.fromJson(Map<String, dynamic> json) {
    return NckNurseModel(
      fullName: json['full_name'] as String,
      licenseNumber: json['license_number'] as String,
      status: json['status'] as String?,
      validTill: json['valid_till'] as String?,
    );
  }
}
