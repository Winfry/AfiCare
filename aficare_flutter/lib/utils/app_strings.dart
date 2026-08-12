/// Centralised translations for Swahili / English.
/// Every user-facing string in the patient experience lives here.
class AppStrings {
  // ── Generic ──────────────────────────────────────────────────────
  static String skip(String lang) => lang == 'sw' ? 'Ruka' : 'Skip';
  static String continue_(String lang) =>
      lang == 'sw' ? 'Endelea' : 'Continue';
  static String saving(String lang) =>
      lang == 'sw' ? 'Inahifadhi…' : 'Saving…';
  static String cancel(String lang) =>
      lang == 'sw' ? 'Ghairi' : 'Cancel';
  static String close(String lang) => lang == 'sw' ? 'Funga' : 'Close';
  static String search(String lang) =>
      lang == 'sw' ? 'Tafuta' : 'Search';
  static String viewAll(String lang) =>
      lang == 'sw' ? 'Ona zote' : 'View all';
  static String save(String lang) => lang == 'sw' ? 'Hifadhi' : 'Save';
  static String confirm(String lang) =>
      lang == 'sw' ? 'Thibitisha' : 'Confirm';
  static String back(String lang) => lang == 'sw' ? 'Rudi' : 'Back';
  static String done(String lang) => lang == 'sw' ? 'Tayari' : 'Done';

  // ── Greeting ────────────────────────────────────────────────────
  static String greeting(String name, String lang) =>
      lang == 'sw' ? 'Habari, $name 👋' : 'Hello, $name 👋';

  static String careSchedule(String lang) =>
      lang == 'sw'
          ? 'Huu hapa ni mpango wako wa matibabu'
          : "Here's your care schedule";

  static String signedInAs(String name, String role, String lang) =>
      lang == 'sw'
          ? 'Umeingia kama $name ($role)'
          : 'Signed in as $name ($role)';

  // ── Hero banner ─────────────────────────────────────────────────
  static String heroTagline(String lang) => lang == 'sw'
      ? 'Joto. Binadamu. Kutia moyo.\nKila hatua hapa ni kukusaidia.'
      : 'Warm. Human. Reassuring.\nEvery step here is here to help you.';

  // ── Checklist ───────────────────────────────────────────────────
  static String checklistTitle(String lang) =>
      lang == 'sw' ? 'Tuanze' : "Let's get you started";
  static String checklistSub(String lang) => lang == 'sw'
      ? 'Hatua chache rahisi — chukua wakati wako.'
      : 'A few simple steps — take them whenever you\'re ready.';
  static String ofDone(String done, String total, String lang) =>
      lang == 'sw' ? '$done ya $total imekamilika' : '$done of $total done';

  static String checklistProfile(String lang) =>
      lang == 'sw' ? 'Kamilisha wasifu wako wa afya' : 'Complete your health profile';
  static String checklistProfileSub(String lang) =>
      lang == 'sw' ? 'Tuambie kidogo kuhusu wewe' : 'Tell us a bit about you';
  static String checklistAppointment(String lang) =>
      lang == 'sw' ? 'Panga miadi yako ya kwanza' : 'Book your first appointment';
  static String checklistAppointmentSub(String lang) =>
      lang == 'sw' ? 'Tafuta daktari na upange miadi' : 'Find a doctor and book';
  static String checklistMedication(String lang) =>
      lang == 'sw' ? 'Ongeza dawa' : 'Add a medication';
  static String checklistMedicationSub(String lang) =>
      lang == 'sw' ? 'Fuatilia dawa zako' : 'Keep track of your medicines';
  static String checklistSharing(String lang) =>
      lang == 'sw' ? 'Anzisha ushirikiano (QR code)' : 'Set up sharing (QR code)';
  static String checklistSharingSub(String lang) =>
      lang == 'sw' ? 'Shiriki rekodi zako kwa usalama' : 'Share your records securely';

  static String btnComplete(String lang) =>
      lang == 'sw' ? 'Kamilisha' : 'Complete';
  static String btnBookNow(String lang) =>
      lang == 'sw' ? 'Panga sasa' : 'Book now';
  static String btnAddNow(String lang) =>
      lang == 'sw' ? 'Ongeza sasa' : 'Add now';
  static String btnSetUp(String lang) =>
      lang == 'sw' ? 'Anzisha' : 'Set up';

  // ── Allergies ───────────────────────────────────────────────────
  static String allergiesLabel(String lang) =>
      lang == 'sw' ? '⚠ Mzio uliorekodiwa' : '⚠ Allergies on file';

  // ── MediLink ────────────────────────────────────────────────────
  static String medilinkId(String lang) => 'MEDILINK ID';
  static String registeredPatient(String lang) =>
      lang == 'sw' ? '✓ Amesajiliwa' : '✓ Registered';
  static String nshaLinked(String lang) =>
      lang == 'sw' ? '✓ Imeunganishwa NHIF / SHA' : '✓ NHIF / SHA linked';
  static String notRegistered(String lang) =>
      lang == 'sw' ? 'Hajasajiliwa' : 'Not registered';

  // ── Trust Banner ────────────────────────────────────────────────
  static String trustTitle(String lang) =>
      lang == 'sw' ? 'Uko mikononi mwema' : "You're in good hands";
  static String trustBody(String lang) => lang == 'sw'
      ? 'Taarifa zako za afya ni za siri na salama. Ni wewe pekee unayeamua nani aione.'
      : 'Your health information is private and secure. Only you decide who sees it.';
  static String trustLearn(String lang) =>
      lang == 'sw' ? 'Jifunze jinsi tunavyokulinda' : 'Learn how we protect you';

  static String privacyTitle(String lang) =>
      lang == 'sw' ? 'Uko mikononi mwema' : "You're in good hands";
  static String privacyBody(String lang) => lang == 'sw'
      ? 'AfiCare huhifadhi rekodi zako kwa usalama na hazishiriki kamwe bila ruhusa yako. '
          'MediLink hukuruhusu kudhibiti nani aone nini — na unaweza kubatilisha ufikiaji wakati wowote.'
      : 'AfiCare keeps your health information private and secure.\n\n'
          '• Your records are encrypted at rest and in transit.\n'
          '• Sharing is always on your terms — you set the access codes.\n'
          '• You can revoke access at any time, right from your settings.';
  static String privacyGotIt(String lang) =>
      lang == 'sw' ? 'Nimeelewa' : 'Got it';

  // ── Care team ───────────────────────────────────────────────────
  static String careTeamTitle(String lang) =>
      lang == 'sw' ? 'Timu yangu ya matibabu' : 'My care team';
  static String careTeamAdd(String lang) =>
      lang == 'sw' ? 'Ongeza mwanachama' : 'Add member';
  static String careTeamEmpty(String lang) =>
      lang == 'sw' ? 'Bado hakuna timu ya matibabu' : 'No care team members yet';
  static String careTeamEmptySub(String lang) =>
      lang == 'sw' ? 'Ongeza wataalamu wako kwa kuweka miadi haraka' : 'Add your specialists for quick booking';
  static String addToTeam(String lang) =>
      lang == 'sw' ? 'Ongeza kwenye timu' : 'Add to Care Team';
  static String labelProvider(String lang) =>
      lang == 'sw' ? 'Weka lebo kwa daktari huyu' : 'Label this provider';
  static String labelProviderHint(String lang) =>
      lang == 'sw' ? 'mf. Daktari wa moyo, Daktari wa familia' : 'e.g. My Cardiologist, Family Doctor';
  static String labelProviderFieldHint(String lang) =>
      lang == 'sw' ? 'mf. Daktari wa moyo katika hospitali ya Moi' : 'e.g. Cardiologist at Moi Hospital';
  static String attachProvider(String lang) =>
      lang == 'sw' ? 'Unganisha na daktari' : 'Attach to provider';
  static String pickProviderHint(String lang) =>
      lang == 'sw' ? 'Chagua daktari anayehusiana na lebo hii' : 'Pick the provider this label refers to';
  static String addedToTeam(String lang) =>
      lang == 'sw' ? 'Imeongezwa kwenye timu yako' : 'Added to your care team';
  static String couldNotAdd(String lang) =>
      lang == 'sw' ? 'Haikuweza kuongezwa — jaribu tena' : 'Could not add — try again';
  static String allProvidersAlready(String lang) =>
      lang == 'sw' ? 'Madaktari wote tayari wako kwenye timu yako.' : 'All providers are already in your care team.';
  static String customDuplicate(String lang) =>
      lang == 'sw' ? 'Daktari huyu tayari yuko kwenye timu yako.' : 'This custom provider is already in your care team.';
  static String editDetails(String lang) =>
      lang == 'sw' ? 'Hariri maelezo' : 'Edit details';
  static String phoneLabel(String lang) =>
      lang == 'sw' ? 'Nambari ya simu' : 'Phone number';
  static String phoneHint(String lang) =>
      lang == 'sw' ? 'mf. 0712 345 678' : 'e.g. 0712 345 678';
  static String hospitalLabel(String lang) =>
      lang == 'sw' ? 'Hospitali / Kliniki' : 'Hospital / Clinic';
  static String hospitalHint(String lang) =>
      lang == 'sw' ? 'mf. Hospitali ya Kenyatta' : 'e.g. Kenyatta National Hospital';

  // ── Appointments ────────────────────────────────────────────────
  static String appointments(String lang) =>
      lang == 'sw' ? 'Miadi' : 'Appointments';
  static String upcomingAppointments(String lang) =>
      lang == 'sw' ? 'Miadi ijayo' : 'Upcoming appointments';
  static String noUpcomingAppointments(String lang) =>
      lang == 'sw' ? 'Hakuna miadi ijayo' : 'No upcoming appointments';
  static String bookFirstAppointment(String lang) => lang == 'sw'
      ? 'Gusa kitufe hapa chini kupanga ya kwanza.'
      : 'Tap the button below to book your first one.';
  static String pastAppointments(String lang, int count) =>
      lang == 'sw'
          ? 'Miadi iliyopita ($count)'
          : 'Past appointments ($count)';
  static String bookAppointment(String lang) =>
      lang == 'sw' ? '+ Panga miadi' : '+ Book Appointment';
  static String telehealth(String lang) =>
      lang == 'sw' ? 'Kwa simu' : 'TELEHEALTH';
  static String inPerson(String lang) =>
      lang == 'sw' ? 'Hudhurio' : 'IN-PERSON';
  static String remoteConsultation(String lang) =>
      lang == 'sw' ? 'Ushauri wa mbali' : 'Remote consultation';
  static String inPersonVisit(String lang) =>
      lang == 'sw' ? 'Ziara ya hudhurio' : 'In-person visit';
  static String confirmed(String lang) =>
      lang == 'sw' ? 'Imethibitishwa' : 'Confirmed';
  static String pending(String lang) =>
      lang == 'sw' ? 'Inasubiri' : 'Pending';
  static String completed(String lang) =>
      lang == 'sw' ? 'Imekamilika' : 'Completed';
  static String cancelled(String lang) =>
      lang == 'sw' ? 'Imeghairiwa' : 'Cancelled';
  static String followUp(String lang) =>
      lang == 'sw' ? 'Ufuatiliaji' : 'Follow-up';
  static String cancelAppointment(String lang) =>
      lang == 'sw' ? 'Ghairi miadi' : 'Cancel appointment';

  // ── Booking flow ────────────────────────────────────────────────
  static String bookAppointmentTitle(String lang) =>
      lang == 'sw' ? 'Panga miadi' : 'Book appointment';
  static String facility(String lang) =>
      lang == 'sw' ? 'Kituo' : 'Facility';
  static String chooseFacility(String lang) =>
      lang == 'sw' ? 'Chagua kituo' : 'Choose facility';
  static String provider(String lang) =>
      lang == 'sw' ? 'Daktari' : 'Provider';
  static String chooseProvider(String lang) =>
      lang == 'sw' ? 'Chagua daktari' : 'Choose provider';
  static String noProvidersRegistered(String lang) => lang == 'sw'
      ? 'Hakuna madaktari waliosajiliwa'
      : 'No providers registered yet. Your appointment will be created as unassigned — a provider can claim it later.';
  static String date(String lang) =>
      lang == 'sw' ? 'Tarehe' : 'Date';
  static String chooseDate(String lang) =>
      lang == 'sw' ? 'Chagua tarehe' : 'Choose date';
  static String time(String lang) =>
      lang == 'sw' ? 'Saa' : 'Time';
  static String chooseTime(String lang) =>
      lang == 'sw' ? 'Chagua saa' : 'Choose time';
  static String type(String lang) =>
      lang == 'sw' ? 'Aina' : 'Type';
  static String typeInPerson(String lang) =>
      lang == 'sw' ? 'Hudhurio' : 'In-Person';
  static String typeTelehealth(String lang) =>
      lang == 'sw' ? 'Kwa simu' : 'Telehealth';
  static String chiefComplaint(String lang) =>
      lang == 'sw' ? 'Dalili kuu (si lazima)' : 'Chief complaint (optional)';
  static String describeSymptoms(String lang) =>
      lang == 'sw' ? 'Elezea dalili zako…' : 'Describe your symptoms…';
  static String bookConfirmBtn(String lang) =>
      lang == 'sw' ? 'Panga miadi' : 'Book appointment';

  // ── Confirmation ────────────────────────────────────────────────
  static String appointmentBooked(String lang) =>
      lang == 'sw' ? 'Miadi imepangwa!' : 'Appointment booked!';
  static String appointmentBookedBody(String lang) => lang == 'sw'
      ? 'Miadi yako imepangwa kwa mafanikio.'
      : 'Your appointment has been successfully scheduled.';
  static String viewMyAppointments(String lang) =>
      lang == 'sw' ? 'Angalia miadi yangu' : 'View my appointments';
  static String backHome(String lang) =>
      lang == 'sw' ? 'Rudi nyumbani' : 'Back to home';
  static String pleaseSelectDateTime(String lang) =>
      lang == 'sw' ? 'Tafadhali chagua tarehe na saa.' : 'Please select a date and time.';
  static String couldNotBook(String lang) =>
      lang == 'sw' ? 'Haikuweza kupanga — jaribu tena' : 'Could not book — try again';
  static String appointmentBookedSuccess(String lang) =>
      lang == 'sw' ? 'Miadi imepangwa kwa mafanikio!' : 'Appointment booked successfully!';

  // ── Cancel confirmation ─────────────────────────────────────────
  static String cancelApptTitle(String lang) =>
      lang == 'sw' ? 'Ghairi miadi?' : 'Cancel appointment?';
  static String cancelApptBody(String type, String date, String lang) =>
      lang == 'sw'
          ? 'Ghairi miadi yako ya ${type == 'telehealth' ? 'kwa simu' : 'hudhurio'} ya $date?'
          : 'Cancel your ${type == 'telehealth' ? 'telehealth' : 'in-person'} appointment on $date?';
  static String keepIt(String lang) =>
      lang == 'sw' ? 'Weka' : 'Keep it';
  static String yesCancel(String lang) =>
      lang == 'sw' ? 'Ndiyo, ghairi' : 'Yes, cancel';

  // ── Onboarding ──────────────────────────────────────────────────
  static String onboardingWelcomeTitle(String lang) =>
      lang == 'sw' ? 'Karibu kwenye AfiCare' : 'Welcome to AfiCare';
  static String onboardingWelcomeBody(String name, String lang) => lang == 'sw'
      ? '$name, tuanze safari yako ya afya. Hatua chache tu — kisha uko tayari.'
      : "$name, let's get your health journey started. A few quick steps — then you're all set.";
  static String onboardingProfileStep(String lang) =>
      lang == 'sw' ? 'Wasifu wako' : 'Your profile';
  static String onboardingProfileSub(String lang) =>
      lang == 'sw' ? 'Tuambie habari za msingi kwa rekodi zako' : 'Tell us the basics for your records';
  static String dobLabel(String lang) =>
      lang == 'sw' ? 'Tarehe ya kuzaliwa' : 'Date of birth';
  static String genderLabel(String lang) =>
      lang == 'sw' ? 'Jinsia' : 'Gender';
  static String bloodTypeLabel(String lang) =>
      lang == 'sw' ? 'Kundi la damu' : 'Blood type';
  static String allergiesLabel2(String lang) =>
      lang == 'sw' ? 'Mizio' : 'Allergies';
  static String emergencyContactLabel(String lang) =>
      lang == 'sw' ? 'Mawasiliano ya dharura' : 'Emergency contact';
  static String contactNameLabel(String lang) =>
      lang == 'sw' ? 'Jina la mawasiliano' : 'Contact name';
  static String contactPhoneLabel(String lang) =>
      lang == 'sw' ? 'Nambari ya simu' : 'Contact phone';
  static String allergyPlaceholder(String lang) =>
      lang == 'sw' ? 'mf. Penicillin' : 'e.g. Penicillin';
  static String dobPlaceholder(String lang) =>
      lang == 'sw' ? 'Siku/Mwezi/Mwaka' : 'DD/MM/YYYY';

  static String onboardingCareStep(String lang) =>
      lang == 'sw' ? 'Panga huduma yako' : 'Set up your care';
  static String onboardingCareSub(String lang) => lang == 'sw'
      ? 'Si lazima — unaweza kuongeza baadaye kwenye wasifu wako.'
      : 'Optional — you can add this later from your profile.';
  static String usualFacility(String lang) =>
      lang == 'sw' ? 'Kituo cha kawaida' : 'Usual facility';
  static String selectFacility(String lang) =>
      lang == 'sw' ? 'Chagua kituo chako' : 'Select your facility';
  static String facilityFallbackHint(String lang) =>
      lang == 'sw' ? 'mf. Hospitali ya Kenyatta' : 'e.g. Kenyatta National Hospital';
  static String dependentsLabel(String lang) =>
      lang == 'sw' ? 'Wanafamilia / wategemezi' : 'Family members / dependents';
  static String dependentHint(String lang) =>
      lang == 'sw' ? 'mf. Mtoto Amara' : 'e.g. Baby Amara';

  static String onboardingQrStep(String lang) =>
      lang == 'sw' ? 'Karibu kwenye AfiCare' : 'Welcome to AfiCare';
  static String onboardingQrTitle(String lang) =>
      lang == 'sw' ? 'Uko tayari!' : "You're all set!";
  static String onboardingQrBody(String fullName, String medilinkId, String lang) =>
      lang == 'sw'
          ? '$fullName, MediLink yako iko tayari.\n\nTumia QR code hii kushiriki rekodi zako kwa usalama na daktari au mhudumu wako.'
          : '$fullName, your MediLink is ready.\n\nUse this QR code to securely share your records with your doctor or caregiver.';
  static String onboardingQrShareBtn(String lang) =>
      lang == 'sw' ? 'Shiriki MediLink' : 'Share MediLink';
  static String onboardingFinishBtn(String lang) =>
      lang == 'sw' ? 'Endelea kwenye Afya Yangu' : 'Continue to My Health';

  static String skipForNow(String lang) =>
      lang == 'sw' ? 'Ruka kwa sasa' : 'Skip for now';
  static String selectDob(String lang) =>
      lang == 'sw' ? 'Tafadhali chagua tarehe ya kuzaliwa' : 'Please select your date of birth';
  static String enterValidDob(String lang) =>
      lang == 'sw' ? 'Tafadhali weka tarehe sahihi (Siku/Mwezi/Mwaka)' : 'Please enter a valid date of birth (DD/MM/YYYY)';
  static String enterEmergencyName(String lang) =>
      lang == 'sw' ? 'Tafadhali weka jina la mawasiliano ya dharura' : 'Please enter an emergency contact name';
  static String enterEmergencyPhone(String lang) =>
      lang == 'sw' ? 'Tafadhali weka nambari ya simu ya dharura' : 'Please enter an emergency contact phone';

  // ── Messaging / empty states ────────────────────────────────────
  static String noData(String lang) =>
      lang == 'sw' ? 'Hakuna data bado' : 'No data yet';
  static String loading(String lang) =>
      lang == 'sw' ? 'Inapakia…' : 'Loading…';

  // ── Quick actions (returning dashboard) ─────────────────────────
  static String prescriptions(String lang) =>
      lang == 'sw' ? 'Maagizo' : 'Prescriptions';
  static String medications(String lang) =>
      lang == 'sw' ? 'Dawa' : 'Medications';
  static String labResults(String lang) =>
      lang == 'sw' ? 'Matokeo ya maabara' : 'Lab results';
  static String healthSummary(String lang) =>
      lang == 'sw' ? 'Muhtasari wa afya' : 'Health summary';
  static String shareRecords(String lang) =>
      lang == 'sw' ? 'Shiriki rekodi' : 'Share records';
  static String expenses(String lang) =>
      lang == 'sw' ? 'Gharama' : 'Expenses';

  // ── Caregiver alerts ────────────────────────────────────────────
  static String caregiverActive(String lang) =>
      lang == 'sw' ? 'Mhudumu ameunganishwa' : 'Caregiver access active';
  static String caregiverCanSee(String lang) =>
      lang == 'sw' ? 'anaweza kuona:' : 'can see:';
  static String caregiverFallback(String lang) => lang == 'sw'
      ? 'Arifa za mhudumu zitaonekana hapa mpango wako wa matibabu unaposasishwa.'
      : 'Caregiver alerts will appear here as your care plan updates.';

  // ── Profile / Settings ──────────────────────────────────────────
  static String profile(String lang) =>
      lang == 'sw' ? 'Wasifu' : 'Profile';
  static String home(String lang) =>
      lang == 'sw' ? 'Nyumbani' : 'Home';
  static String messages(String lang) =>
      lang == 'sw' ? 'Ujumbe' : 'Messages';
  static String records(String lang) =>
      lang == 'sw' ? 'Rekodi' : 'Records';
  static String logout(String lang) =>
      lang == 'sw' ? 'Ondoka' : 'Log out';
  static String settings(String lang) =>
      lang == 'sw' ? 'Mipangilio' : 'Settings';
}
