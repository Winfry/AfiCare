import 'package:flutter/material.dart';

/// The patient app's navigation, in one place.
///
/// Every patient page is a route under `/patient`, and every route renders
/// inside [PatientShell] (a GoRouter `ShellRoute`), so the sidebar, top bar
/// and bottom bar stay on screen wherever the patient goes — as in the
/// approved "AfiCare Today" design. The sidebar, the "More of AfiCare"
/// page, the phone's bottom bar, the breadcrumb and the dependant guard
/// all read from the tables below, so a page added here is reachable
/// everywhere at once.
abstract final class PatientRoutes {
  static const today = '/patient';
  static const appointments = '/patient/appointments';
  static const medications = '/patient/medications';
  static const records = '/patient/records';
  static const messages = '/patient/messages';
  static const more = '/patient/more';
  static const profile = '/patient/profile';
  static const dependents = '/patient/dependents';
  static const scan = '/patient/scan';
}

class PatientDest {
  const PatientDest({
    required this.icon,
    required this.label,
    required this.route,
    this.adultOnly = false,
    this.phoneOnly = false,
  });

  final IconData icon;
  final String label;
  final String route;

  /// Hidden while a guardian is viewing a child's profile (the spec's
  /// `data-adult`), and redirected away from if a child is switched to
  /// while the page is open.
  final bool adultOnly;

  /// Listed on the More page only on phones, where it has no sidebar slot.
  final bool phoneOnly;
}

/// The sidebar, exactly as in the design: four everyday destinations and
/// two for people and support. Everything else lives on the More page.
const patientSidebar = <String, List<PatientDest>>{
  'Your care': [
    PatientDest(icon: Icons.home_outlined, label: 'Today', route: PatientRoutes.today),
    PatientDest(icon: Icons.calendar_today_outlined, label: 'Appointments', route: PatientRoutes.appointments),
    PatientDest(icon: Icons.medication_outlined, label: 'Medications', route: PatientRoutes.medications),
    PatientDest(icon: Icons.description_outlined, label: 'Health records', route: PatientRoutes.records),
  ],
  'People & support': [
    PatientDest(icon: Icons.chat_bubble_outline, label: 'Messages', route: PatientRoutes.messages),
    PatientDest(icon: Icons.grid_view_rounded, label: 'More of AfiCare', route: PatientRoutes.more),
  ],
};

/// The "More of AfiCare" page. Every patient page that is not in the
/// sidebar must be listed here, or it has no way in.
const patientMore = <String, List<PatientDest>>{
  // Health records and Messages are in the sidebar on wide screens; the
  // phone's bottom bar has no room for them, so they are repeated here.
  'Your record': [
    PatientDest(icon: Icons.description_outlined, label: 'Health records', route: PatientRoutes.records, phoneOnly: true),
    PatientDest(icon: Icons.chat_bubble_outline, label: 'Messages', route: PatientRoutes.messages, phoneOnly: true),
    PatientDest(icon: Icons.science_outlined, label: 'Lab results', route: '/patient/labs'),
    PatientDest(icon: Icons.check_circle_outline, label: 'Adherence log', route: '/patient/adherence'),
    PatientDest(icon: Icons.groups_2_outlined, label: 'Care team', route: '/patient/care-team'),
    PatientDest(icon: Icons.north_east, label: 'Referrals', route: '/patient/referrals'),
    PatientDest(icon: Icons.ios_share, label: 'Share my records', route: '/patient/share'),
  ],
  'Health & wellbeing': [
    PatientDest(icon: Icons.emergency_outlined, label: 'Emergency support', route: '/patient/emergency'),
    PatientDest(icon: Icons.psychology_outlined, label: 'Mental wellbeing', route: '/patient/mental-health', adultOnly: true),
    PatientDest(icon: Icons.vaccines_outlined, label: 'Vaccinations', route: '/patient/vaccinations'),
    PatientDest(icon: Icons.alarm_outlined, label: 'Medicine reminders', route: '/patient/medication-reminders'),
    PatientDest(icon: Icons.manage_search, label: 'Medicine checker', route: '/patient/drug-interactions'),
    PatientDest(icon: Icons.pregnant_woman_outlined, label: 'Maternal care', route: '/patient/anc', adultOnly: true),
    PatientDest(icon: Icons.male_outlined, label: "Men's health", route: '/patient/mens-health', adultOnly: true),
  ],
  'Support & access': [
    PatientDest(icon: Icons.accessible, label: 'PWD / disability support', route: '/patient/pwd'),
    PatientDest(icon: Icons.accessibility_new_outlined, label: 'Accessibility', route: '/patient/accessibility'),
    PatientDest(icon: Icons.handshake_outlined, label: 'Caregiver access', route: '/patient/caregiver-portal', adultOnly: true),
    PatientDest(icon: Icons.person_outline, label: 'Profile & MediLink ID', route: PatientRoutes.profile),
    PatientDest(icon: Icons.family_restroom_outlined, label: 'People I care for', route: PatientRoutes.dependents, adultOnly: true),
  ],
  // All account-level: these show the bill payer's costs, receipts and
  // cover, which belong to the account holder rather than to whichever
  // profile is being viewed. Marked adult-only so they do not appear
  // under a dependant, where they would read as that child's finances.
  'Costs & cover': [
    PatientDest(icon: Icons.credit_card_outlined, label: 'Medication costs', route: '/patient/medication-costs', adultOnly: true),
    PatientDest(icon: Icons.receipt_long_outlined, label: 'Receipts', route: '/patient/receipt-upload', adultOnly: true),
    PatientDest(icon: Icons.shield_outlined, label: 'Insurance claims', route: '/patient/insurance-claims', adultOnly: true),
    PatientDest(icon: Icons.account_balance_wallet_outlined, label: 'Expenses', route: '/patient/expenses', adultOnly: true),
  ],
};

/// Pages with no nav entry of their own, named for the breadcrumb.
const _unlistedTitles = {
  '/patient/health': 'Health records',
};

/// The phone's bottom bar: Today, Visits, Medicines, More.
const patientBottomRoutes = [
  PatientRoutes.today,
  PatientRoutes.appointments,
  PatientRoutes.medications,
  PatientRoutes.more,
];

Iterable<PatientDest> get _allDests sync* {
  for (final g in patientSidebar.values) {
    yield* g;
  }
  for (final g in patientMore.values) {
    yield* g;
  }
}

/// The top-level patient page a location belongs to: `/patient/labs/x`
/// belongs to `/patient/labs`.
String patientSection(String location) {
  final path = Uri.parse(location).path;
  final parts = path.split('/').where((p) => p.isNotEmpty).toList();
  if (parts.length < 2) return PatientRoutes.today;
  return '/${parts[0]}/${parts[1]}';
}

PatientDest? patientDestFor(String location) {
  final section = patientSection(location);
  for (final d in _allDests) {
    if (d.route == section) return d;
  }
  return null;
}

/// Name of the page at [location], for the breadcrumb.
String patientTitleFor(String location) {
  final section = patientSection(location);
  return patientDestFor(location)?.label ?? _unlistedTitles[section] ?? 'AfiCare';
}

/// True when the page at [location] is one of the sidebar's own
/// destinations (it has no "back to More" link).
bool isPatientSidebarRoute(String location) {
  final section = patientSection(location);
  return patientSidebar.values.any((g) => g.any((d) => d.route == section));
}

/// True when the page at [location] must not be shown under a dependant.
bool isPatientAdultOnly(String location) => patientDestFor(location)?.adultOnly ?? false;

/// The sidebar entry to light up for [location]: its own entry, or "More
/// of AfiCare" for everything reached from the More page.
String patientSidebarRouteFor(String location) =>
    isPatientSidebarRoute(location) ? patientSection(location) : PatientRoutes.more;

/// The bottom-bar slot to light up for [location] on a phone.
int patientBottomIndexFor(String location) {
  final section = patientSection(location);
  final i = patientBottomRoutes.indexOf(section);
  return i == -1 ? patientBottomRoutes.length - 1 : i;
}
