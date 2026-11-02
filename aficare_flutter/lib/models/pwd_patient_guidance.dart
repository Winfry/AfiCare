// ================================================================
// AfiCare MediLink — PWD suggestions, in the patient's own words
//
// The rule engine (services/pwd_rule_engine.dart) is written for
// clinicians: "Suicide Risk Screening — CRITICAL — use the Columbia
// scale, document risk level". That is right on the consultation
// screen and wrong on the patient's own page, where it reads like a
// frightening label with nothing to do about it.
//
// This file gives every rule a version written *to* the patient: what
// it is, why it matters, and what to ask the clinic. The engine still
// decides which suggestions apply and in what order, so the two sides
// never disagree about *what* is suggested — only about how it is said.
//
// Rules that are instructions to the clinician (provider notes) have no
// patient version. Suicide-risk screening has none either: the patient
// gets support instead (see [PwdPatientGuidance.offersSupportLines]).
// A rule added to the engine without a patient version here is left
// off the patient's page rather than shown in clinician language; a
// test checks that every rule is covered.
// ================================================================

import '../services/pwd_rule_engine.dart';
import 'disability_profile.dart';

/// One suggestion as the patient sees it.
class PwdPatientTip {
  const PwdPatientTip({
    required this.id,
    required this.title,
    required this.body,
    required this.ask,
    required this.category,
    this.topic,
  });

  /// The engine rule this comes from.
  final String id;

  final String title;

  /// What it is and why it matters.
  final String body;

  /// What to ask or do at the clinic.
  final String ask;

  final RecommendationCategory category;

  /// Tips that say the same thing for different disabilities (blood
  /// pressure for both sight loss and long-term illness) share a topic,
  /// and only the first is shown.
  final String? topic;
}

class PwdPatientGuidance {
  PwdPatientGuidance._();

  /// Engine rules with no patient version on purpose.
  static const notForPatients = {
    'mental_suicide_risk', // replaced by support lines
  };

  /// The patient's suggestions for [profile], most important first.
  static List<PwdPatientTip> tipsFor(DisabilityProfile profile, {PwdRuleEngine engine = const PwdRuleEngine()}) {
    final tips = <PwdPatientTip>[];
    final topics = <String>{};
    for (final rec in engine.getRecommendations(profile)) {
      final tip = tipFor(rec, profile);
      if (tip == null) continue;
      if (tip.topic != null && !topics.add(tip.topic!)) continue;
      tips.add(tip);
    }
    return tips;
  }

  /// Anyone who records a mental health condition is offered someone to
  /// talk to, whatever the severity.
  static bool offersSupportLines(DisabilityProfile profile) =>
      profile.disabilityTypes.contains(DisabilityType.mentalHealth);

  /// The patient version of [rec], or null when there isn't one.
  static PwdPatientTip? tipFor(PwdRecommendation rec, DisabilityProfile profile) {
    if (rec.category == RecommendationCategory.providerNote) return null;
    if (notForPatients.contains(rec.id)) return null;
    final words = _words(rec.id, profile);
    if (words == null) return null;
    final (title, body, ask, topic) = words;
    return PwdPatientTip(id: rec.id, title: title, body: body, ask: ask, category: rec.category, topic: topic);
  }

  /// Every rule id that has a patient version (for tests).
  static bool hasWordsFor(String id) => _words(id, _anyProfile) != null;

  static final _anyProfile = DisabilityProfile(
    patientId: '',
    disabilityTypes: const [],
    severity: DisabilitySeverity.moderate,
    assistiveDevices: const [],
    lastUpdated: DateTime(2026),
    updatedBy: 'patient',
  );

  static (String, String, String, String?)? _words(String id, DisabilityProfile profile) {
    final wheelchair = profile.assistiveDevices.any((d) => d.toLowerCase().contains('wheelchair'));
    return switch (id) {
      // ── Sight ──────────────────────────────────────────────────
      'visual_eye_pressure' => (
          'Yearly eye pressure check',
          'High pressure inside the eye (glaucoma) can slowly take away more sight, often with no pain or '
              'warning. A quick, painless test at an eye clinic finds it early.',
          'Ask for an eye pressure check once a year.',
          null,
        ),
      'visual_fundus_exam' => (
          'Yearly check of the back of the eye',
          'An eye specialist looks at the back of the eye (the retina), sometimes after drops that widen the '
              'pupil. It finds problems such as damage from diabetes early, while they can still be treated.',
          'Ask for a check of the back of your eyes once a year.',
          'retina',
        ),
      'visual_vitamin_a' => (
          'Vitamin A',
          'Too little vitamin A can harm eyesight. It is found in orange and dark green foods such as '
              'carrots, sweet potatoes, mangoes and sukuma wiki, and in liver, eggs and milk.',
          'Ask whether you need a vitamin A check or supplement. Do not take high-dose supplements on your own.',
          null,
        ),
      'visual_bp_monitoring' || 'chronic_bp_monitoring' => (
          'Blood pressure checks',
          'High blood pressure has no signs you can feel. Over time it can harm the eyes, heart and kidneys.',
          'Ask to have your blood pressure checked at every visit.',
          'blood_pressure',
        ),
      'visual_ophthalmologist_referral' => (
          'See an eye specialist',
          'An eye specialist (ophthalmologist) can do a full eye check and tell you about low-vision help, '
              'such as magnifiers and training to make the most of the sight you have.',
          'Ask your clinic to refer you to an eye specialist.',
          null,
        ),
      'visual_orientation_mobility' => (
          'Getting around safely',
          'Orientation and mobility trainers teach skills for moving around safely and confidently, '
              'such as using a white cane.',
          'Ask whether there is orientation and mobility training near you.',
          null,
        ),

      // ── Hearing ────────────────────────────────────────────────
      'hearing_audiometry' => (
          'Yearly hearing test',
          'A hearing test shows whether your hearing has changed and whether a hearing aid needs adjusting.',
          'Ask for a hearing test once a year.',
          null,
        ),
      'hearing_ear_health' => (
          'Ear check',
          'Ear wax or an ear infection can make hearing worse, and both are usually easy to treat.',
          'Ask the clinic to look in your ears. Do not push cotton buds or sharp objects into your ears.',
          null,
        ),
      'hearing_device_check' => (
          'Looking after your hearing aid',
          'Keep it clean and dry and the batteries fresh. If it whistles, hurts, or helps less than before, '
              'it may need adjusting.',
          'Bring your hearing aid to appointments and ask for it to be checked.',
          null,
        ),
      'hearing_mental_health' => (
          'How you are feeling',
          'Living with hearing loss can feel lonely or tiring at times, and low mood is common. '
              'It is worth talking about.',
          'Tell your clinic how you have been feeling. You can also try the Mental wellbeing check in this app.',
          'feelings',
        ),
      'hearing_ent_referral' => (
          'See an ear specialist',
          'An ear, nose and throat (ENT) specialist can look more closely at your hearing and plan treatment '
              'or hearing support.',
          'Ask your clinic whether you should be referred.',
          null,
        ),

      // ── Moving ─────────────────────────────────────────────────
      'mobility_pressure_sore' => (
          'Protecting your skin from pressure sores',
          'Sitting or lying in one position for a long time can cause sores on the bottom, hips and heels. '
              'Change position often, and check your skin every day (a mirror or a helper can make this easier) '
              'for red patches that do not fade.',
          wheelchair
              ? 'Ask your clinic to check your skin at every visit, and about the right cushion for your wheelchair. '
                  'Get help quickly if you find a sore or broken skin.'
              : 'Ask your clinic to check your skin. Get help quickly if you find a sore or broken skin.',
          null,
        ),
      'mobility_dvt' => (
          'Blood clots in the legs',
          'Moving less makes blood clots in the legs more likely. Signs are one leg that becomes swollen, '
              'painful, warm or red.',
          'Ask your clinic about your risk. Get help the same day if you notice these signs. Call 999 or 112 '
              'if you suddenly feel short of breath or have chest pain.',
          null,
        ),
      'mobility_physio_referral' => (
          'Physiotherapy',
          'A physiotherapist can teach exercises that keep your joints moving, ease stiffness, and help you '
              'stay as independent as possible.',
          'Ask to be referred to a physiotherapist.',
          null,
        ),
      'mobility_bone_density' => (
          'Strong bones',
          'Moving less can make bones thinner and easier to break. A bone density scan (DEXA) measures this.',
          'Ask whether a bone density scan is right for you.',
          null,
        ),
      'mobility_cardiovascular' => (
          'Heart health',
          'Sitting a lot raises the risk of heart disease. Checking blood pressure, weight and cholesterol, '
              'and exercise that suits your body, help protect your heart.',
          'Ask for a heart health check, and about exercise you can do.',
          null,
        ),
      'mobility_uti_screening' => (
          'Catheter care and urine infections',
          'Using a catheter makes urine infections more likely. Wash your hands before and after handling it, '
              'and keep the area clean. Signs of infection include fever, cloudy or smelly urine, pain, or '
              'feeling unwell or confused.',
          'Ask your clinic to check your urine and to show you how to care for your catheter. '
              'Get help quickly if you have a fever.',
          null,
        ),

      // ── Thinking and learning ──────────────────────────────────
      'cognitive_caregiver_required' => profile.requiresCaregiverForConsent
          ? (
              'Bring your carer or guardian',
              'Your care team has noted that a parent, carer or guardian should be with you when health '
                  'decisions are made and when agreeing to treatment.',
              'Bring them to your appointments.',
              null,
            )
          : (
              'Help with health decisions',
              'If health decisions feel hard, you can bring someone you trust, such as a family member or '
                  'carer, to help you understand and decide.',
              'Ask your clinic how they can include the people who support you.',
              null,
            ),
      'cognitive_mental_state' => (
          'Memory and thinking check',
          'A short set of questions helps your care team notice any changes in memory or thinking over time.',
          'Ask about a memory and thinking check at your visits.',
          null,
        ),
      'cognitive_medication_support' => (
          'Help with medicines',
          'A pill box marked with the days of the week, phone reminders, or help from a carer can make it '
              'easier to take the right medicine at the right time. Your doctor may also be able to make your '
              'medicines simpler.',
          'Ask your clinic about ways to make your medicines easier. You can set medicine reminders in this app.',
          null,
        ),
      'cognitive_dental' => (
          'Dentist check',
          'Teeth and gums are easy to forget about. A yearly dentist visit helps prevent pain and infection.',
          'Ask to see a dentist once a year, and for help with brushing if it is hard.',
          null,
        ),
      'cognitive_nutrition' => (
          'Eating, drinking and weight',
          'Your care team can check your weight and how well you eat and swallow. Coughing or choking when '
              'eating or drinking is worth mentioning.',
          'Ask for a weight and diet check.',
          null,
        ),
      'cognitive_seizure' => (
          'Seizures (fits)',
          'Seizures are more common in people with an intellectual disability. If you have ever had a fit, '
              'blank spells or sudden jerking, tell your care team.',
          'Ask your clinic about seizures, and what to do if one happens.',
          null,
        ),

      // ── Speech ─────────────────────────────────────────────────
      'speech_therapist_referral' => (
          'Speech and language therapy',
          'A speech and language therapist can help with communication, including picture boards, apps and '
              'other communication aids.',
          'Ask to be referred to a speech and language therapist.',
          null,
        ),
      'speech_aac_check' => (
          'Your communication aid',
          'If you use a communication aid, make sure it works and is charged, and that the people around you '
              'know how to use it.',
          'Ask for help if it needs repairing or upgrading.',
          null,
        ),
      'speech_mental_health' => (
          'How you are feeling',
          'Finding it hard to be understood can be frustrating and lonely at times, and low mood is common. '
              'It is worth talking about.',
          'Tell your clinic how you have been feeling. You can also try the Mental wellbeing check in this app.',
          'feelings',
        ),
      'speech_swallowing' => (
          'Swallowing',
          'Some people who have trouble speaking also have trouble swallowing. Coughing, choking, or a wet, '
              'gurgly voice when eating or drinking are signs to mention.',
          'Ask for a swallowing check.',
          null,
        ),

      // ── Long-term illness ──────────────────────────────────────
      'chronic_hba1c' => (
          'Blood sugar test (HbA1c), if you have diabetes',
          'This blood test shows your average blood sugar over the past 3 months, so you and your doctor can '
              'see how well diabetes is controlled.',
          'If you have diabetes or were told your sugar is high, ask how often you need it, often every 3 to 6 months.',
          null,
        ),
      'chronic_kidney_function' => (
          'Kidney check',
          'Long-term illnesses such as diabetes and high blood pressure can slowly harm the kidneys without '
              'any signs. Simple blood and urine tests find this early.',
          'Ask for a kidney check at least once a year.',
          null,
        ),
      'chronic_foot_exam' => (
          'Foot check',
          'Diabetes and poor blood flow can cause numb feet and sores that heal slowly. Look at your feet every '
              'day for cuts, blisters or colour changes.',
          'Ask your clinic to check your feet at least once a year, and more often if you have had a foot sore before.',
          null,
        ),
      'chronic_eye_exam' => (
          'Eye check for diabetes',
          'Diabetes can harm the back of the eye before you notice any change in your sight. A yearly eye check '
              'finds it early.',
          'If you have diabetes, ask for an eye check once a year.',
          'retina',
        ),
      'chronic_medication_adherence' => (
          'Your medicines',
          'Take your medicines as prescribed, even when you feel well. If you miss doses, have side effects, or '
              'find them too costly, tell your doctor. There may be a simpler or cheaper option.',
          'Bring all your medicines to appointments so they can be reviewed.',
          null,
        ),
      'chronic_lipid_profile' => (
          'Cholesterol test',
          'Many long-term illnesses raise the risk of heart disease. A blood test for cholesterol helps check this.',
          'Ask for a cholesterol (lipid) test once a year.',
          null,
        ),

      // ── Mental health ──────────────────────────────────────────
      'mental_monthly_assessment' => (
          'Regular check-ins',
          'Talking regularly with your care team about your mood, worries, sleep and daily life helps you both '
              'notice changes early.',
          'Ask how often you should have a check-in. You can also try the Mental wellbeing check in this app.',
          null,
        ),
      'mental_medication_adherence' => (
          'Keep taking your medicines',
          'Do not stop your medicines suddenly, even if you feel better. Stopping suddenly can make you unwell. '
              'If you have side effects or miss doses, your doctor can help.',
          'Talk to your doctor before making any change to your medicines.',
          null,
        ),
      'mental_sleep' => (
          'Sleep',
          'Poor sleep can make mood and worry worse, and low mood can spoil sleep.',
          'Tell your clinic if you sleep too little, too much, or wake often.',
          null,
        ),
      'mental_social_support' => (
          'People around you',
          'Feeling alone can make things harder. Family, friends, support groups or a social worker can help.',
          'Ask your clinic about support groups or a social worker near you.',
          null,
        ),
      'mental_psychiatrist_referral' => (
          'Specialist mental health care',
          'If treatment is not helping enough, a psychiatrist (a doctor who specialises in mental health) can '
              'take a closer look.',
          'Ask whether a referral would help you.',
          null,
        ),
      _ => null,
    };
  }
}
