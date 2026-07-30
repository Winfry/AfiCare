class AppStrings {
  static String greeting(String name, String lang) =>
      lang == 'sw' ? 'Habari, $name' : 'Hello, $name';

  static String subtitle(String date, String lang) =>
      lang == 'sw' ? '$date · Hakuna miadi' : '$date · No appointments';

  static String appointmentCardTitle(String lang) =>
      lang == 'sw' ? 'Miada ijayo' : 'Next Appointment';

  static String noAppointments(String lang) =>
      lang == 'sw' ? 'Hakuna miadi ijayo' : 'No upcoming appointments';

  static String bookAppointment(String lang) =>
      lang == 'sw' ? 'Weka miadi' : 'Book appointment';

  static String vitalsTitle(String lang) =>
      lang == 'sw' ? 'Afya yako' : 'Your Vitals';

  static String noVitals(String lang) =>
      lang == 'sw' ? 'Hakuna data ya afya bado' : 'No vitals recorded yet';

  static String medicationsTitle(String lang) =>
      lang == 'sw' ? 'Dawa za leo' : "Today's Medications";

  static String noMedications(String lang) =>
      lang == 'sw' ? 'Hakuna dawa kwa leo' : 'No medications due today';

  static String taken(String lang) => lang == 'sw' ? 'Nimekunywa' : 'Taken';

  static String skip(String lang) => lang == 'sw' ? 'Ruka' : 'Skip';

  static String quickActions(String lang) =>
      lang == 'sw' ? 'Vitendo' : 'Quick Actions';

  static String recentActivity(String lang) =>
      lang == 'sw' ? 'Shughuli za hivi karibuni' : 'Recent Activity';

  static String seeAll(String lang) => lang == 'sw' ? 'Ona zote' : 'See all';

  static String swahili(String lang) =>
      lang == 'sw' ? 'Kiswahili' : 'English';
}
