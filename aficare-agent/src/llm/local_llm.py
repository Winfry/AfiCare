"""
Local LLM Integration for AfiCare Agent
Handles Llama model loading and medical text generation
"""

from typing import Dict, List, Optional, Any
import logging
import asyncio
from pathlib import Path

try:
    from llama_cpp import Llama
except ImportError:
    Llama = None
    logging.warning("llama-cpp-python not installed. LLM features will be disabled.")

from .prompt_templates import PromptTemplates
from .response_parser import ResponseParser

logger = logging.getLogger(__name__)


class LocalLLM:
    """Local Llama model for medical text generation and analysis"""
    
    def __init__(self, config):
        self.config = config
        self.model = None
        self.prompt_templates = PromptTemplates()
        self.response_parser = ResponseParser()
        self._load_model()
    
    def _load_model(self):
        """Load the Llama model"""
        
        if Llama is None:
            logger.error("llama-cpp-python not available. Install with: pip install llama-cpp-python")
            return
        
        try:
            model_path = self.config.get('llm.model_path')
            
            if not Path(model_path).exists():
                logger.error(f"Model file not found: {model_path}")
                return
            
            logger.info(f"Loading Llama model from {model_path}")
            
            self.model = Llama(
                model_path=model_path,
                n_ctx=self.config.get('llm.context_length', 4096),
                n_gpu_layers=self.config.get('llm.n_gpu_layers', 0),
                verbose=self.config.get('llm.verbose', False)
            )
            
            logger.info("Llama model loaded successfully")
            
        except Exception as e:
            logger.error(f"Failed to load Llama model: {str(e)}")
            self.model = None
    
    def is_loaded(self) -> bool:
        """Check if model is loaded and ready"""
        return self.model is not None
    
    async def analyze_case(
        self,
        patient_data: Any,
        condition_matches: List[Dict],
        triage_result: Any
    ) -> Dict[str, Any]:
        """
        Analyze a medical case using the LLM
        
        Args:
            patient_data: Patient information
            condition_matches: Matched conditions from rule engine
            triage_result: Triage assessment result
            
        Returns:
            Dictionary with LLM analysis results
        """
        
        if not self.is_loaded():
            logger.warning("LLM not loaded, returning empty analysis")
            return {"error": "LLM not available", "confidence": 0.0}
        
        try:
            # Generate prompt for case analysis
            prompt = self.prompt_templates.create_case_analysis_prompt(
                patient_data, condition_matches, triage_result
            )
            
            # Generate response
            response = await self._generate_response(prompt)
            
            # Parse and structure the response
            analysis = self.response_parser.parse_case_analysis(response)
            
            return analysis
            
        except Exception as e:
            logger.error(f"Error in LLM case analysis: {str(e)}")
            return {"error": str(e), "confidence": 0.0}
    
    async def generate_patient_education(
        self,
        condition: str,
        language: str = "en"
    ) -> str:
        """
        Generate patient education content for a condition
        
        Args:
            condition: Medical condition name
            language: Language code (en, sw, lg)
            
        Returns:
            Patient education text
        """
        
        if not self.is_loaded():
            return "Patient education not available - LLM not loaded"
        
        try:
            prompt = self.prompt_templates.create_patient_education_prompt(
                condition, language
            )
            
            response = await self._generate_response(prompt)
            
            return self.response_parser.parse_patient_education(response)
            
        except Exception as e:
            logger.error(f"Error generating patient education: {str(e)}")
            return f"Error generating education content: {str(e)}"
    
    async def suggest_differential_diagnosis(
        self,
        symptoms: List[str],
        age: int,
        gender: str,
        current_diagnoses: List[str]
    ) -> List[str]:
        """
        Suggest differential diagnoses using LLM
        
        Args:
            symptoms: List of symptoms
            age: Patient age
            gender: Patient gender
            current_diagnoses: Already considered diagnoses
            
        Returns:
            List of suggested differential diagnoses
        """
        
        if not self.is_loaded():
            return []
        
        try:
            prompt = self.prompt_templates.create_differential_diagnosis_prompt(
                symptoms, age, gender, current_diagnoses
            )
            
            response = await self._generate_response(prompt)
            
            return self.response_parser.parse_differential_diagnoses(response)
            
        except Exception as e:
            logger.error(f"Error generating differential diagnoses: {str(e)}")
            return []
    
    async def generate_treatment_plan(
        self,
        condition: str,
        patient_age: int,
        patient_weight: Optional[float] = None,
        allergies: List[str] = None,
        current_medications: List[str] = None
    ) -> Dict[str, Any]:
        """
        Generate treatment plan using LLM
        
        Args:
            condition: Primary diagnosis
            patient_age: Patient age
            patient_weight: Patient weight in kg
            allergies: Known allergies
            current_medications: Current medications
            
        Returns:
            Treatment plan dictionary
        """
        
        if not self.is_loaded():
            return {"error": "LLM not available"}
        
        try:
            prompt = self.prompt_templates.create_treatment_plan_prompt(
                condition, patient_age, patient_weight, allergies, current_medications
            )
            
            response = await self._generate_response(prompt)
            
            return self.response_parser.parse_treatment_plan(response)
            
        except Exception as e:
            logger.error(f"Error generating treatment plan: {str(e)}")
            return {"error": str(e)}
    
    async def _generate_response(self, prompt: str) -> str:
        """
        Generate response from the LLM
        
        Args:
            prompt: Input prompt
            
        Returns:
            Generated text response
        """
        
        if not self.is_loaded():
            raise RuntimeError("LLM model not loaded")
        
        # Run in thread pool to avoid blocking
        loop = asyncio.get_event_loop()
        
        def _generate():
            return self.model(
                prompt,
                max_tokens=self.config.get('llm.max_tokens', 512),
                temperature=self.config.get('llm.temperature', 0.3),
                top_p=0.9,
                stop=["</response>", "\n\n---", "Human:", "Assistant:"]
            )
        
        result = await loop.run_in_executor(None, _generate)
        
        return result['choices'][0]['text'].strip()
    
    async def translate_text(
        self,
        text: str,
        target_language: str,
        medical_context: bool = True
    ) -> str:
        """
        Translate medical text to target language
        
        Args:
            text: Text to translate
            target_language: Target language code
            medical_context: Whether to use medical translation context
            
        Returns:
            Translated text
        """
        
        if not self.is_loaded():
            return text  # Return original if LLM not available
        
        try:
            prompt = self.prompt_templates.create_translation_prompt(
                text, target_language, medical_context
            )
            
            response = await self._generate_response(prompt)
            
            return self.response_parser.parse_translation(response)
            
        except Exception as e:
            logger.error(f"Error in translation: {str(e)}")
            return text  # Return original on error
    
    def get_model_info(self) -> Dict[str, Any]:
        """Get information about the loaded model"""
        
        if not self.is_loaded():
            return {"status": "not_loaded"}
        
        return {
            "status": "loaded",
            "model_path": self.config.get('llm.model_path'),
            "context_length": self.config.get('llm.context_length'),
            "gpu_layers": self.config.get('llm.n_gpu_layers'),
            "temperature": self.config.get('llm.temperature')
        }