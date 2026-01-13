"""
Response Parser for LLM Medical Outputs
Parses and structures LLM responses for medical applications
"""

import json
import re
from typing import Dict, List, Any, Optional
import logging

logger = logging.getLogger(__name__)


class ResponseParser:
    """Parser for medical LLM responses"""
    
    def __init__(self):
        self.confidence_keywords = {
            'very_high': ['certain', 'definite', 'clear', 'obvious', 'unmistakable'],
            'high': ['likely', 'probable', 'strong', 'confident', 'evident'],
            'moderate': ['possible', 'moderate', 'reasonable', 'fair', 'suggests'],
            'low': ['unlikely', 'doubtful', 'weak', 'minimal', 'slight'],
            'very_low': ['very unlikely', 'highly doubtful', 'negligible', 'remote']
        }
    
    def parse_case_analysis(self, response: str) -> Dict[str, Any]:
        """
        Parse comprehensive case analysis response
        
        Args:
            response: Raw LLM response text
            
        Returns:
            Structured analysis dictionary
        """
        
        try:
            # Try to extract JSON if present
            json_match = re.search(r'\{.*\}', response, re.DOTALL)
            if json_match:
                try:
                    return json.loads(json_match.group())
                except json.JSONDecodeError:
                    pass
            
            # Fallback to text parsing
            analysis = {
                'clinical_reasoning': self._extract_section(response, 'clinical reasoning'),
                'additional_questions': self._extract_list_section(response, 'additional questions'),
                'immediate_actions': self._extract_list_section(response, 'immediate actions'),
                'treatment_recommendations': self._extract_list_section(response, 'treatment'),
                'patient_education': self._extract_list_section(response, 'patient education'),
                'follow_up': self._extract_section(response, 'follow'),
                'red_flags': self._extract_list_section(response, 'red flags'),
                'confidence': self._extract_confidence(response)
            }
            
            return analysis
            
        except Exception as e:
            logger.error(f"Error parsing case analysis: {str(e)}")
            return {
                'error': f"Failed to parse response: {str(e)}",
                'raw_response': response,
                'confidence': 0.0
            }
    
    def parse_patient_education(self, response: str) -> str:
        """
        Parse patient education content
        
        Args:
            response: Raw LLM response
            
        Returns:
            Formatted patient education text
        """
        
        # Clean up the response
        cleaned = self._clean_response(response)
        
        # Structure the content if it's not already structured
        if not self._is_structured_content(cleaned):
            return self._structure_education_content(cleaned)
        
        return cleaned
    
    def parse_differential_diagnoses(self, response: str) -> List[str]:
        """
        Parse differential diagnosis suggestions
        
        Args:
            response: Raw LLM response
            
        Returns:
            List of differential diagnoses
        """
        
        diagnoses = []
        
        # Look for numbered or bulleted lists
        patterns = [
            r'^\d+\.\s*([^:\n]+)',  # Numbered lists
            r'^[-*•]\s*([^:\n]+)',   # Bullet points
            r'^([A-Z][a-z\s]+)(?:\s*[-:])',  # Condition names followed by colon/dash
        ]
        
        lines = response.split('\n')
        
        for line in lines:
            line = line.strip()
            if not line:
                continue
                
            for pattern in patterns:
                match = re.match(pattern, line, re.MULTILINE)
                if match:
                    diagnosis = match.group(1).strip()
                    if diagnosis and len(diagnosis) > 2:
                        diagnoses.append(diagnosis)
                    break
        
        # Remove duplicates while preserving order
        seen = set()
        unique_diagnoses = []
        for diagnosis in diagnoses:
            if diagnosis.lower() not in seen:
                seen.add(diagnosis.lower())
                unique_diagnoses.append(diagnosis)
        
        return unique_diagnoses[:10]  # Limit to top 10
    
    def parse_treatment_plan(self, response: str) -> Dict[str, Any]:
        """
        Parse treatment plan response
        
        Args:
            response: Raw LLM response
            
        Returns:
            Structured treatment plan
        """
        
        try:
            # Try JSON parsing first
            json_match = re.search(r'\{.*\}', response, re.DOTALL)
            if json_match:
                try:
                    return json.loads(json_match.group())
                except json.JSONDecodeError:
                    pass
            
            # Text parsing fallback
            plan = {
                'immediate_treatment': self._extract_treatment_section(response, 'immediate'),
                'medications': self._extract_medications(response),
                'monitoring': self._extract_list_section(response, 'monitoring'),
                'patient_instructions': self._extract_list_section(response, 'instructions'),
                'follow_up': self._extract_section(response, 'follow'),
                'referral_criteria': self._extract_list_section(response, 'referral'),
                'duration': self._extract_duration(response)
            }
            
            return plan
            
        except Exception as e:
            logger.error(f"Error parsing treatment plan: {str(e)}")
            return {
                'error': f"Failed to parse treatment plan: {str(e)}",
                'raw_response': response
            }
    
    def parse_translation(self, response: str) -> str:
        """
        Parse translation response
        
        Args:
            response: Raw LLM response
            
        Returns:
            Translated text
        """
        
        # Clean the response
        cleaned = self._clean_response(response)
        
        # Remove common prefixes/suffixes from translation responses
        prefixes_to_remove = [
            'translation:', 'translated text:', 'here is the translation:',
            'the translation is:', 'in [language] this would be:'
        ]
        
        for prefix in prefixes_to_remove:
            if cleaned.lower().startswith(prefix):
                cleaned = cleaned[len(prefix):].strip()
        
        # Remove quotes if the entire response is quoted
        if cleaned.startswith('"') and cleaned.endswith('"'):
            cleaned = cleaned[1:-1]
        
        return cleaned
    
    def _extract_section(self, text: str, section_keyword: str) -> str:
        """Extract a specific section from text"""
        
        # Look for section headers
        patterns = [
            rf'{section_keyword}[:\s]*\n([^#\n]*(?:\n(?!#)[^#\n]*)*)',
            rf'\d+\.\s*{section_keyword}[:\s]*\n([^#\n]*(?:\n(?!#|\d+\.)[^#\n]*)*)',
            rf'#{1,3}\s*{section_keyword}[:\s]*\n([^#\n]*(?:\n(?!#)[^#\n]*)*)'
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE | re.MULTILINE)
            if match:
                return match.group(1).strip()
        
        return ""
    
    def _extract_list_section(self, text: str, section_keyword: str) -> List[str]:
        """Extract a list from a specific section"""
        
        section_text = self._extract_section(text, section_keyword)
        if not section_text:
            return []
        
        # Extract list items
        items = []
        lines = section_text.split('\n')
        
        for line in lines:
            line = line.strip()
            if not line:
                continue
            
            # Remove list markers
            line = re.sub(r'^[-*•]\s*', '', line)
            line = re.sub(r'^\d+\.\s*', '', line)
            
            if line and len(line) > 2:
                items.append(line)
        
        return items
    
    def _extract_treatment_section(self, text: str, treatment_type: str) -> Dict[str, Any]:
        """Extract treatment information"""
        
        section = self._extract_section(text, f"{treatment_type} treatment")
        
        return {
            'description': section,
            'medications': self._extract_medications(section),
            'non_pharmacological': self._extract_non_pharma_treatments(section)
        }
    
    def _extract_medications(self, text: str) -> List[Dict[str, str]]:
        """Extract medication information"""
        
        medications = []
        
        # Look for medication patterns
        med_patterns = [
            r'([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s+(\d+(?:\.\d+)?)\s*(mg|g|ml|tablets?)\s*(?:(?:every|q)\s*(\d+)\s*(hours?|h|times?\s+daily|daily))?',
            r'([A-Z][a-z]+)\s*[-:]\s*([^,\n]+)'
        ]
        
        for pattern in med_patterns:
            matches = re.finditer(pattern, text, re.IGNORECASE)
            for match in matches:
                med_info = {
                    'name': match.group(1),
                    'dosage': match.group(2) if len(match.groups()) > 1 else '',
                    'unit': match.group(3) if len(match.groups()) > 2 else '',
                    'frequency': match.group(4) if len(match.groups()) > 3 else ''
                }
                medications.append(med_info)
        
        return medications
    
    def _extract_non_pharma_treatments(self, text: str) -> List[str]:
        """Extract non-pharmacological treatments"""
        
        non_pharma_keywords = [
            'rest', 'hydration', 'diet', 'exercise', 'physiotherapy',
            'counseling', 'lifestyle', 'education', 'monitoring'
        ]
        
        treatments = []
        lines = text.split('\n')
        
        for line in lines:
            line = line.strip().lower()
            for keyword in non_pharma_keywords:
                if keyword in line:
                    treatments.append(line)
                    break
        
        return treatments
    
    def _extract_duration(self, text: str) -> str:
        """Extract treatment duration"""
        
        duration_patterns = [
            r'(?:for|duration[:\s]*)\s*(\d+\s*(?:days?|weeks?|months?))',
            r'(\d+\s*(?:days?|weeks?|months?))\s*(?:of\s+)?treatment'
        ]
        
        for pattern in duration_patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return match.group(1)
        
        return ""
    
    def _extract_confidence(self, text: str) -> float:
        """Extract confidence level from text"""
        
        text_lower = text.lower()
        
        # Check for explicit confidence percentages
        confidence_match = re.search(r'confidence[:\s]*(\d+)%', text_lower)
        if confidence_match:
            return float(confidence_match.group(1)) / 100
        
        # Check for confidence keywords
        for level, keywords in self.confidence_keywords.items():
            for keyword in keywords:
                if keyword in text_lower:
                    confidence_map = {
                        'very_high': 0.9,
                        'high': 0.75,
                        'moderate': 0.6,
                        'low': 0.4,
                        'very_low': 0.2
                    }
                    return confidence_map.get(level, 0.5)
        
        return 0.5  # Default moderate confidence
    
    def _clean_response(self, response: str) -> str:
        """Clean and format response text"""
        
        # Remove response tags
        response = re.sub(r'</?response>', '', response)
        
        # Remove excessive whitespace
        response = re.sub(r'\n\s*\n\s*\n', '\n\n', response)
        
        # Strip leading/trailing whitespace
        response = response.strip()
        
        return response
    
    def _is_structured_content(self, text: str) -> bool:
        """Check if content is already well-structured"""
        
        structure_indicators = [
            r'^\d+\.',  # Numbered lists
            r'^#{1,3}\s',  # Headers
            r'^\*\*[^*]+\*\*',  # Bold headers
            r'^[-*•]\s'  # Bullet points
        ]
        
        lines = text.split('\n')
        structured_lines = 0
        
        for line in lines:
            line = line.strip()
            if not line:
                continue
            
            for pattern in structure_indicators:
                if re.match(pattern, line):
                    structured_lines += 1
                    break
        
        return structured_lines > len(lines) * 0.3  # 30% of lines are structured
    
    def _structure_education_content(self, content: str) -> str:
        """Add structure to unstructured education content"""
        
        # Simple structuring - add headers for common sections
        structured = content
        
        # Add section headers based on content
        if 'what is' in content.lower():
            structured = re.sub(
                r'(what is [^?]+\?)',
                r'## \1',
                structured,
                flags=re.IGNORECASE
            )
        
        return structured