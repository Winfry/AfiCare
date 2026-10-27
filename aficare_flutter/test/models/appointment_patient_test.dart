import 'package:flutter_test/flutter_test.dart';

import 'package:aficare_flutter/models/appointment_patient_model.dart';

void main() {
  AppointmentPatient from(Map<String, dynamic> extra) =>
      AppointmentPatient.fromJson({'appointment_id': 'a1', 'patient_name': 'Brian Wanjiru', ...extra});

  test('an account holder is just their name', () {
    expect(from({'is_dependant': false}).label, 'Brian Wanjiru');
  });

  test("a dependant says whose they are", () {
    expect(from({'is_dependant': true, 'guardian_name': 'Mary Wanjiru', 'relationship': 'child'}).label,
        "Brian Wanjiru · Mary Wanjiru's child");
    expect(from({'is_dependant': true, 'guardian_name': 'Mary Wanjiru', 'relationship': 'grandchild'}).label,
        "Brian Wanjiru · Mary Wanjiru's grandchild");
  });

  test('a dependant with another relationship is "cared for by"', () {
    expect(from({'is_dependant': true, 'guardian_name': 'Mary Wanjiru', 'relationship': 'other'}).label,
        'Brian Wanjiru · cared for by Mary Wanjiru');
  });

  test('a missing name never shows blank', () {
    expect(AppointmentPatient.fromJson({'appointment_id': 'a1', 'patient_name': '  '}).label, 'Patient');
    expect(from({'is_dependant': true}).label, 'Brian Wanjiru');
  });
}
