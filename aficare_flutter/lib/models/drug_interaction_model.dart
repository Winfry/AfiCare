class DrugInteraction {
  final String drug1;
  final String drug2;
  final String severity; // 'severe', 'moderate', 'mild'
  final String description;
  final String recommendation;

  const DrugInteraction({
    required this.drug1,
    required this.drug2,
    required this.severity,
    required this.description,
    required this.recommendation,
  });

  static String severityLabel(String severity) {
    switch (severity) {
      case 'severe': return 'Severe — Avoid Combination';
      case 'moderate': return 'Moderate — Monitor Closely';
      case 'mild': return 'Mild — Low Risk';
      default: return severity;
    }
  }
}

class DrugInteractionService {
  static const List<DrugInteraction> knownInteractions = [
    DrugInteraction(
      drug1: 'Warfarin', drug2: 'Aspirin',
      severity: 'severe',
      description: 'Increased risk of bleeding when combined',
      recommendation: 'Avoid combination or monitor INR very closely',
    ),
    DrugInteraction(
      drug1: 'Metformin', drug2: 'Alcohol',
      severity: 'severe',
      description: 'Alcohol increases risk of lactic acidosis with metformin',
      recommendation: 'Limit alcohol intake; inform your doctor',
    ),
    DrugInteraction(
      drug1: 'Lisinopril', drug2: 'Potassium',
      severity: 'moderate',
      description: 'ACE inhibitors can increase potassium levels',
      recommendation: 'Monitor potassium levels regularly',
    ),
    DrugInteraction(
      drug1: 'Amlodipine', drug2: 'Simvastatin',
      severity: 'moderate',
      description: 'Amlodipine can increase simvastatin levels, raising risk of muscle damage',
      recommendation: 'Limit simvastatin dose to 20mg when combined',
    ),
    DrugInteraction(
      drug1: 'Omeprazole', drug2: 'Clopidogrel',
      severity: 'severe',
      description: 'Omeprazole reduces the effectiveness of clopidogrel',
      recommendation: 'Use pantoprazole instead if PPI needed with clopidogrel',
    ),
    DrugInteraction(
      drug1: 'Metoprolol', drug2: 'Verapamil',
      severity: 'severe',
      description: 'Combined use can cause severe bradycardia and heart block',
      recommendation: 'Avoid combination; use alternative if needed',
    ),
    DrugInteraction(
      drug1: 'Fluoxetine', drug2: 'Tramadol',
      severity: 'severe',
      description: 'Increased risk of serotonin syndrome',
      recommendation: 'Avoid combination; use alternative pain medication',
    ),
    DrugInteraction(
      drug1: 'Ibuprofen', drug2: 'Lisinopril',
      severity: 'moderate',
      description: 'NSAIDs can reduce the blood pressure-lowering effect of ACE inhibitors',
      recommendation: 'Use acetaminophen instead; if NSAID required, monitor BP closely',
    ),
    DrugInteraction(
      drug1: 'Amoxicillin', drug2: 'Methotrexate',
      severity: 'moderate',
      description: 'Penicillins can reduce methotrexate clearance',
      recommendation: 'Monitor methotrexate levels and kidney function',
    ),
    DrugInteraction(
      drug1: 'Spironolactone', drug2: 'Potassium',
      severity: 'severe',
      description: 'Spironolactone is potassium-sparing; additional potassium can cause hyperkalemia',
      recommendation: 'Avoid potassium supplements; monitor serum potassium',
    ),
    DrugInteraction(
      drug1: 'Ciprofloxacin', drug2: 'Calcium',
      severity: 'moderate',
      description: 'Fluoroquinolone absorption reduced by calcium',
      recommendation: 'Take ciprofloxacin 2 hours before or 6 hours after calcium',
    ),
    DrugInteraction(
      drug1: 'Levothyroxine', drug2: 'Calcium',
      severity: 'moderate',
      description: 'Calcium supplements can reduce levothyroxine absorption',
      recommendation: 'Take levothyroxine 4 hours before calcium supplements',
    ),
    DrugInteraction(
      drug1: 'Warfarin', drug2: 'Ibuprofen',
      severity: 'severe',
      description: 'NSAIDs increase bleeding risk with warfarin',
      recommendation: 'Use acetaminophen for pain relief instead',
    ),
    DrugInteraction(
      drug1: 'Metformin', drug2: 'Contrast Dye',
      severity: 'severe',
      description: 'IV contrast with metformin increases risk of lactic acidosis',
      recommendation: 'Stop metformin 48 hours before and after contrast procedures',
    ),
    DrugInteraction(
      drug1: 'Amlodipine', drug2: 'Grapefruit',
      severity: 'mild',
      description: 'Grapefruit juice can slightly increase amlodipine levels',
      recommendation: 'Avoid large quantities of grapefruit juice',
    ),
    DrugInteraction(
      drug1: 'Enalapril', drug2: 'Spironolactone',
      severity: 'moderate',
      description: 'Combined use can cause hyperkalemia',
      recommendation: 'Monitor potassium levels closely, especially in elderly',
    ),
  ];

  /// Check if any of the given medications have known interactions.
  static List<DrugInteraction> checkInteractions(List<String> medications) {
    if (medications.length < 2) return [];

    final results = <DrugInteraction>[];
    final lowerMeds = medications.map((m) => m.toLowerCase()).toList();

    for (var i = 0; i < lowerMeds.length; i++) {
      for (var j = i + 1; j < lowerMeds.length; j++) {
        for (final interaction in knownInteractions) {
          final d1Lower = interaction.drug1.toLowerCase();
          final d2Lower = interaction.drug2.toLowerCase();
          if ((lowerMeds[i].contains(d1Lower) && lowerMeds[j].contains(d2Lower)) ||
              (lowerMeds[i].contains(d2Lower) && lowerMeds[j].contains(d1Lower))) {
            results.add(interaction);
          }
        }
      }
    }

    return results;
  }

  /// Check if a single new medication interacts with existing medications.
  static List<DrugInteraction> checkNewMedication(
      String newMed, List<String> existingMeds) {
    return checkInteractions([newMed, ...existingMeds]);
  }
}
