"""
Prompt Templates for Medical LLM Interactions
Contains structured prompts for various medical AI tasks
"""

from typing import List, Dict, Optional, Any
from datetime import datetime


class PromptTemplates:
    """Medical prompt templates for LLM interactions"""
    
    def __init__(self):
        self.system_context = """You are AfiCare, an AI medical assistant designed for healthcare settings in Africa. 
You provide evidence-based medical guidance while being culturally sensitive and appropriate for resource-limited settings.

IMPORTANT GUIDELINES:
- Always emphasize the need for proper medical evaluation
- Consider local disease prevalence and available treatments
- Be culturally sensitive and use appropriate language
- Provide practical, actionable recommendations
- Acknowledge limitations and recommend referral when needed
- Focus on conditions common in African healthcare settings"""

    def create_case_analysis_prompt(
        self,
        patient_data: Any,
        condition_matches: List[Dict],
        triage_result: Any
    ) -> str:
        """Create prompt for comprehensive case analysis"""
        
        prompt = f"""{self.system_context}

PATIENT CASE ANALYSIS

Patient Information:
- Age: {patient_data.age} years
- Gender: {patient_data.gender}
- Chief Complaint: {patient_data.chief_complaint}

Symptoms:
{self._format_symptoms(patient_data.symptoms)}

Vital Signs:
{self._format_vital_signs(patient_data.vital_signs)}

Medical History:
{self._format_medical_history(patient_data.medical_history)}

Current Medications:
{self._format_medications(patient_data.current_medications)}

Preliminary Assessment:
Triage Level: {triage_result.level if hasattr(triage_result, 'level') else 'Unknown'}

Condition Matches from Rule Engine:
{self._format_condition_matches(condition_matches)}

Please provide a comprehensive analysis including:
1. Clinical reasoning for the most likely diagnoses
2. Additional questions or examinations needed
3. Recommended immediate actions
4. Treatment recommendations appropriate for this setting
5. Patient education points
6. Follow-up requirements
7. Red flags to watch for

Format your response as structured JSON with these sections.

<response>"""
        
        return prompt
    
    def create_patient_education_prompt(
        self,
        condition: str,
        language: str = "en"
    ) -> str:
        """Create prompt for patient education content"""
        
        language_names = {
            "en": "English",
            "sw": "Kiswahili", 
            "lg": "Luganda"
        }
        
        lang_name = language_names.get(language, "English")
        
        prompt = f"""{self.system_context}

PATIENT EDUCATION CONTENT

Generate patient education material for: {condition}
Language: {lang_name}

Requirements:
- Use simple, clear language appropriate for patients with varying education levels
- Include cultural context relevant to African communities
- Focus on practical, actionable advice
- Address common concerns and misconceptions
- Include prevention strategies where applicable
- Mention when to seek immediate medical care

Structure the content with:
1. What is {condition}? (simple explanation)
2. Common symptoms to watch for
3. Treatment and self-care instructions
4. Prevention tips
5. When to return to the clinic immediately
6. Lifestyle recommendations

Keep the language compassionate and reassuring while being medically accurate.

<response>"""
        
        return prompt
    
    def create_differential_diagnosis_prompt(
        self,
        symptoms: List[str],
        age: int,
        gender: str,
        current_diagnoses: List[str]
    ) -> str:
        """Create prompt for differential diagnosis suggestions"""
        
        prompt = f"""{self.system_context}

DIFFERENTIAL DIAGNOSIS ANALYSIS

Patient Profile:
- Age: {age} years
- Gender: {gender}

Presenting Symptoms:
{chr(10).join(f"- {symptom}" for symptom in symptoms)}

Already Considered Diagnoses:
{chr(10).join(f"- {diagnosis}" for diagnosis in current_diagnoses)}

Please suggest additional differential diagnoses that should be considered, particularly focusing on:
1. Conditions common in African healthcare settings
2. Infectious diseases prevalent in the region
3. Conditions that might be missed or overlooked
4. Emergency conditions that require immediate attention

For each suggested diagnosis, provide:
- Condition name
- Key distinguishing features
- Recommended diagnostic tests (if available in resource-limited settings)
- Urgency level

Prioritize conditions by likelihood and clinical significance.

<response>"""
        
        return prompt
    
    def create_treatment_plan_prompt(
        self,
        condition: str,
        patient_age: int,
        patient_weight: Optional[float] = None,
        allergies: List[str] = None,
        current_medications: List[str] = None
    ) -> str:
        """Create prompt for treatment plan generation"""
        
        allergies = allergies or []
        current_medications = current_medications or []
        
        prompt = f"""{self.system_context}

TREATMENT PLAN DEVELOPMENT

Primary Diagnosis: {condition}
Patient Age: {patient_age} years
Patient Weight: {patient_weight if patient_weight else 'Not specified'} kg

Known Allergies:
{chr(10).join(f"- {allergy}" for allergy in allergies) if allergies else "- None reported"}

Current Medications:
{chr(10).join(f"- {med}" for med in current_medications) if current_medications else "- None"}

Please develop a comprehensive treatment plan including:

1. IMMEDIATE TREATMENT:
   - First-line medications with dosages appropriate for age/weight
   - Alternative medications if first-line not available
   - Non-pharmacological interventions

2. MONITORING:
   - What to monitor and how often
   - Warning signs for complications
   - Expected timeline for improvement

3. PATIENT INSTRUCTIONS:
   - How to take medications
   - Lifestyle modifications
   - Activity restrictions if any

4. FOLLOW-UP:
   - When to return for follow-up
   - What to expect during recovery
   - Long-term management if applicable

5. REFERRAL CRITERIA:
   - When to refer to higher level of care
   - Specific indications for emergency referral

Consider medication availability and cost in resource-limited settings.
Avoid medications that may interact with current treatments or trigger allergies.

<response>"""
        
        return prompt
    
    def create_translation_prompt(
        self,
        text: str,
        target_language: str,
        medical_context: bool = True
    ) -> str:
        """Create prompt for medical text translation"""
        
        language_names = {
            "en": "English",
            "sw": "Kiswahili",
            "lg": "Luganda"
        }
        
        target_lang_name = language_names.get(target_language, target_language)
        
        context_note = ""
        if medical_context:
            context_note = """
This is medical content. Ensure:
- Medical terms are translated accurately
- Cultural appropriateness is maintained
- The meaning remains precise and clear
- Use commonly understood terms when possible"""
        
        prompt = f"""{self.system_context}

MEDICAL TEXT TRANSLATION

Translate the following text to {target_lang_name}:

"{text}"

{context_note}

Provide only the translated text without additional commentary.

<response>"""
        
        return prompt
    
    def _format_symptoms(self, symptoms: List[str]) -> str:
        """Format symptoms list for prompt"""
        if not symptoms:
            return "- No symptoms reported"
        return "\n".join(f"- {symptom}" for symptom in symptoms)
    
    def _format_vital_signs(self, vital_signs: Dict[str, float]) -> str:
        """Format vital signs for prompt"""
        if not vital_signs:
            return "- No vital signs recorded"
        
        formatted = []
        for sign, value in vital_signs.items():
            if sign == 'temperature':
                formatted.append(f"- Temperature: {value}°C")
            elif sign == 'systolic_bp':
                formatted.append(f"- Blood Pressure: {value}/{vital_signs.get('diastolic_bp', '?')} mmHg")
            elif sign == 'pulse':
                formatted.append(f"- Pulse: {value} bpm")
            elif sign == 'respiratory_rate':
                formatted.append(f"- Respiratory Rate: {value} breaths/min")
            elif sign == 'oxygen_saturation':
                formatted.append(f"- Oxygen Saturation: {value}%")
            else:
                formatted.append(f"- {sign.replace('_', ' ').title()}: {value}")
        
        return "\n".join(formatted)
    
    def _format_medical_history(self, history: List[str]) -> str:
        """Format medical history for prompt"""
        if not history:
            return "- No significant medical history"
        return "\n".join(f"- {item}" for item in history)
    
    def _format_medications(self, medications: List[str]) -> str:
        """Format medications list for prompt"""
        if not medications:
            return "- No current medications"
        return "\n".join(f"- {med}" for med in medications)
    
    def _format_condition_matches(self, matches: List[Dict]) -> str:
        """Format condition matches for prompt"""
        if not matches:
            return "- No specific conditions identified by rule engine"
        
        formatted = []
        for match in matches:
            confidence = match.get('confidence', 0.0)
            condition = match.get('name', 'Unknown')
            formatted.append(f"- {condition}: {confidence:.1%} confidence")
        
        return "\n".join(formatted)