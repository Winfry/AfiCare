"""
AfiCare Medical Agent - LangChain Implementation
Modern AI agent using LangChain, LlamaIndex, and RAG for medical consultations
"""

from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass
from datetime import datetime
import logging
import json
import os
from pathlib import Path

# LangChain imports
try:
    from langchain.agents import AgentExecutor, create_react_agent
    from langchain.tools import Tool
    from langchain.memory import ConversationBufferWindowMemory
    from langchain.prompts import PromptTemplate
    from langchain_core.messages import HumanMessage, SystemMessage
    from langchain_community.llms import Ollama
    from langchain_community.embeddings import HuggingFaceEmbeddings
    
    # LlamaIndex imports
    from llama_index.core import VectorStoreIndex, Document, Settings
    from llama_index.core.retrievers import VectorIndexRetriever
    from llama_index.core.query_engine import RetrieverQueryEngine
    from llama_index.embeddings.huggingface import HuggingFaceEmbedding
    from llama_index.llms.ollama import Ollama as LlamaOllama
    
    # Vector store
    from langchain_community.vectorstores import Chroma
    
    FRAMEWORKS_AVAILABLE = True
    
except ImportError as e:
    print(f"⚠️ AI frameworks not available: {e}")
    print("💡 Install with: pip install langchain llamaindex chromadb")
    FRAMEWORKS_AVAILABLE = False

logger = logging.getLogger(__name__)

@dataclass
class PatientData:
    """Patient information structure"""
    patient_id: str
    age: int
    gender: str
    symptoms: List[str]
    vital_signs: Dict[str, float]
    medical_history: List[str]
    current_medications: List[str]
    chief_complaint: str

@dataclass
class ConsultationResult:
    """Consultation outcome structure"""
    patient_id: str
    timestamp: datetime
    triage_level: str
    suspected_conditions: List[Dict[str, Any]]
    recommendations: List[str]
    referral_needed: bool
    follow_up_required: bool
    confidence_score: float
    reasoning_chain: List[str]  # New: Chain of thought
    evidence_sources: List[str]  # New: RAG sources

class LangChainMedicalAgent:
    """
    Modern medical AI agent using LangChain + LlamaIndex
    Features:
    - Chain of Thought reasoning
    - RAG for medical knowledge
    - Multi-agent collaboration
    - Memory management
    """
    
    def __init__(self, config: Optional[Dict] = None):
        if not FRAMEWORKS_AVAILABLE:
            raise ImportError("AI frameworks not available. Please install requirements.")
        
        self.config = config or {}
        self.knowledge_base_path = Path(__file__).parent.parent.parent / "data" / "knowledge_base"
        
        # Initialize LLM
        self.llm = self._initialize_llm()
        
        # Initialize embeddings
        self.embeddings = HuggingFaceEmbeddings(
            model_name="sentence-transformers/all-MiniLM-L6-v2"
        )
        
        # Initialize RAG system
        self.knowledge_index = self._build_knowledge_index()
        self.query_engine = self._create_query_engine()
        
        # Initialize memory
        self.memory = ConversationBufferWindowMemory(
            k=10,  # Remember last 10 interactions
            return_messages=True
        )
        
        # Create specialized agents
        self.triage_agent = self._create_triage_agent()
        self.diagnosis_agent = self._create_diagnosis_agent()
        self.treatment_agent = self._create_treatment_agent()
        
        logger.info("🤖 LangChain Medical Agent initialized successfully!")
    
    def _initialize_llm(self):
        """Initialize the language model"""
        try:
            # Try Ollama first (local)
            llm = Ollama(
                model="llama3.2:3b",
                temperature=0.1,  # Low temperature for medical accuracy
                top_p=0.9
            )
            logger.info("✅ Ollama LLM initialized")
            return llm
        except Exception as e:
            logger.warning(f"⚠️ Ollama not available: {e}")
            # Fallback to mock LLM for demo
            return MockLLM()
    
    def _build_knowledge_index(self):
        """Build RAG knowledge index from medical knowledge base"""
        documents = []
        
        # Load medical conditions
        conditions_dir = self.knowledge_base_path / "conditions"
        if conditions_dir.exists():
            for json_file in conditions_dir.glob("*.json"):
                try:
                    with open(json_file, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                    
                    # Convert JSON to documents
                    doc_text = self._json_to_text(data, json_file.stem)
                    documents.append(Document(
                        text=doc_text,
                        metadata={"source": str(json_file), "type": "medical_condition"}
                    ))
                except Exception as e:
                    logger.warning(f"⚠️ Could not load {json_file}: {e}")
        
        # Configure LlamaIndex
        Settings.embed_model = HuggingFaceEmbedding(
            model_name="sentence-transformers/all-MiniLM-L6-v2"
        )
        Settings.llm = LlamaOllama(model="llama3.2:3b", request_timeout=60.0)
        
        # Create index
        if documents:
            index = VectorStoreIndex.from_documents(documents)
            logger.info(f"✅ Knowledge index built with {len(documents)} documents")
            return index
        else:
            logger.warning("⚠️ No documents found for knowledge index")
            return None
    
    def _json_to_text(self, data: Dict, filename: str) -> str:
        """Convert JSON medical data to searchable text"""
        text_parts = [f"Medical Knowledge: {filename}"]
        
        def extract_text(obj, prefix=""):
            if isinstance(obj, dict):
                for key, value in obj.items():
                    if isinstance(value, (dict, list)):
                        extract_text(value, f"{prefix}{key}: ")
                    else:
                        text_parts.append(f"{prefix}{key}: {value}")
            elif isinstance(obj, list):
                for item in obj:
                    if isinstance(item, str):
                        text_parts.append(f"{prefix}{item}")
                    else:
                        extract_text(item, prefix)
        
        extract_text(data)
        return "\n".join(text_parts)
    
    def _create_query_engine(self):
        """Create RAG query engine"""
        if self.knowledge_index:
            retriever = VectorIndexRetriever(
                index=self.knowledge_index,
                similarity_top_k=5
            )
            return RetrieverQueryEngine(retriever=retriever)
        return None
    
    def _create_triage_agent(self):
        """Create specialized triage agent"""
        triage_prompt = PromptTemplate(
            input_variables=["patient_data", "vital_signs"],
            template="""
            You are an expert emergency triage nurse with 20 years of experience.
            
            Patient Information:
            {patient_data}
            
            Vital Signs:
            {vital_signs}
            
            Based on this information, determine the triage level:
            - EMERGENCY: Life-threatening, needs immediate attention
            - URGENT: Serious condition, needs attention within 1 hour
            - LESS_URGENT: Stable condition, can wait 2-4 hours
            - NON_URGENT: Minor condition, routine care
            
            Consider these danger signs:
            - Severe difficulty breathing
            - Chest pain with radiation
            - Altered consciousness
            - Severe bleeding
            - Signs of shock
            - High fever with altered mental status
            
            Provide your triage decision with reasoning.
            """
        )
        
        return {
            "prompt": triage_prompt,
            "role": "Emergency Triage Specialist"
        }
    
    def _create_diagnosis_agent(self):
        """Create specialized diagnosis agent"""
        diagnosis_prompt = PromptTemplate(
            input_variables=["patient_data", "symptoms", "medical_history", "rag_context"],
            template="""
            You are an expert diagnostic physician with expertise in internal medicine.
            
            Patient Information:
            Age: {patient_data}
            Symptoms: {symptoms}
            Medical History: {medical_history}
            
            Relevant Medical Knowledge:
            {rag_context}
            
            Using differential diagnosis principles:
            1. List the most likely conditions based on symptoms
            2. Consider the patient's age, gender, and medical history
            3. Rank conditions by probability
            4. Explain your reasoning for each condition
            5. Identify any red flags or concerning features
            
            Provide a structured differential diagnosis with confidence levels.
            """
        )
        
        return {
            "prompt": diagnosis_prompt,
            "role": "Diagnostic Physician"
        }
    
    def _create_treatment_agent(self):
        """Create specialized treatment agent"""
        treatment_prompt = PromptTemplate(
            input_variables=["diagnosis", "patient_data", "contraindications"],
            template="""
            You are an expert clinical pharmacist and treatment specialist.
            
            Diagnosis: {diagnosis}
            Patient: {patient_data}
            Contraindications: {contraindications}
            
            Provide evidence-based treatment recommendations:
            1. First-line treatments with dosages
            2. Alternative treatments if first-line contraindicated
            3. Monitoring parameters
            4. Patient education points
            5. Follow-up recommendations
            6. When to seek emergency care
            
            Consider:
            - Patient age and weight for dosing
            - Drug interactions with current medications
            - Allergies and contraindications
            - Cost-effectiveness for resource-limited settings
            - WHO Essential Medicines List preferences
            
            Provide structured treatment plan.
            """
        )
        
        return {
            "prompt": treatment_prompt,
            "role": "Clinical Treatment Specialist"
        }
    
    async def conduct_consultation(self, patient_data: PatientData) -> ConsultationResult:
        """
        Conduct comprehensive medical consultation using multi-agent approach
        """
        logger.info(f"🩺 Starting LangChain consultation for {patient_data.patient_id}")
        
        reasoning_chain = []
        evidence_sources = []
        
        try:
            # Step 1: RAG Knowledge Retrieval
            rag_context = ""
            if self.query_engine:
                query = f"Patient with symptoms: {', '.join(patient_data.symptoms)}. Age: {patient_data.age}, Gender: {patient_data.gender}"
                rag_response = self.query_engine.query(query)
                rag_context = str(rag_response)
                evidence_sources.append("Medical Knowledge Base")
                reasoning_chain.append(f"Retrieved relevant medical knowledge for symptoms: {', '.join(patient_data.symptoms)}")
            
            # Step 2: Triage Assessment
            triage_input = {
                "patient_data": f"Age: {patient_data.age}, Gender: {patient_data.gender}, Chief Complaint: {patient_data.chief_complaint}",
                "vital_signs": str(patient_data.vital_signs)
            }
            
            triage_response = await self._run_agent(self.triage_agent, triage_input)
            triage_level = self._extract_triage_level(triage_response)
            reasoning_chain.append(f"Triage assessment: {triage_level}")
            
            # Step 3: Diagnostic Assessment
            diagnosis_input = {
                "patient_data": f"Age: {patient_data.age}, Gender: {patient_data.gender}",
                "symptoms": ", ".join(patient_data.symptoms),
                "medical_history": ", ".join(patient_data.medical_history),
                "rag_context": rag_context
            }
            
            diagnosis_response = await self._run_agent(self.diagnosis_agent, diagnosis_input)
            suspected_conditions = self._extract_conditions(diagnosis_response)
            reasoning_chain.append(f"Differential diagnosis completed with {len(suspected_conditions)} conditions")
            
            # Step 4: Treatment Recommendations
            treatment_input = {
                "diagnosis": diagnosis_response,
                "patient_data": f"Age: {patient_data.age}, Medications: {', '.join(patient_data.current_medications)}",
                "contraindications": "Check for drug allergies and interactions"
            }
            
            treatment_response = await self._run_agent(self.treatment_agent, treatment_input)
            recommendations = self._extract_recommendations(treatment_response)
            reasoning_chain.append(f"Treatment plan generated with {len(recommendations)} recommendations")
            
            # Step 5: Final Assessment
            referral_needed = triage_level in ["EMERGENCY", "URGENT"]
            follow_up_required = any("follow" in rec.lower() for rec in recommendations)
            confidence_score = self._calculate_confidence(suspected_conditions, triage_level)
            
            result = ConsultationResult(
                patient_id=patient_data.patient_id,
                timestamp=datetime.now(),
                triage_level=triage_level,
                suspected_conditions=suspected_conditions,
                recommendations=recommendations,
                referral_needed=referral_needed,
                follow_up_required=follow_up_required,
                confidence_score=confidence_score,
                reasoning_chain=reasoning_chain,
                evidence_sources=evidence_sources
            )
            
            logger.info(f"✅ LangChain consultation completed for {patient_data.patient_id}")
            return result
            
        except Exception as e:
            logger.error(f"❌ LangChain consultation failed: {str(e)}")
            # Fallback to basic assessment
            return self._fallback_consultation(patient_data)
    
    async def _run_agent(self, agent: Dict, inputs: Dict) -> str:
        """Run a specialized agent with given inputs"""
        try:
            prompt = agent["prompt"].format(**inputs)
            
            # Use LLM to generate response
            if hasattr(self.llm, 'invoke'):
                response = self.llm.invoke(prompt)
            else:
                response = self.llm(prompt)
            
            return response
        except Exception as e:
            logger.error(f"❌ Agent execution failed: {e}")
            return f"Agent {agent['role']} encountered an error: {str(e)}"
    
    def _extract_triage_level(self, response: str) -> str:
        """Extract triage level from agent response"""
        response_upper = response.upper()
        
        if "EMERGENCY" in response_upper:
            return "EMERGENCY"
        elif "URGENT" in response_upper:
            return "URGENT"
        elif "LESS_URGENT" in response_upper or "LESS URGENT" in response_upper:
            return "LESS_URGENT"
        else:
            return "NON_URGENT"
    
    def _extract_conditions(self, response: str) -> List[Dict[str, Any]]:
        """Extract suspected conditions from diagnosis response"""
        # Simple extraction - in production, use more sophisticated parsing
        conditions = []
        
        # Look for common condition patterns
        common_conditions = [
            "malaria", "pneumonia", "hypertension", "diabetes", "tuberculosis",
            "pcos", "endometriosis", "fibroids", "preeclampsia", "anemia"
        ]
        
        for condition in common_conditions:
            if condition.lower() in response.lower():
                # Estimate confidence based on context
                confidence = 0.7 if f"likely {condition}" in response.lower() else 0.5
                conditions.append({
                    "name": condition,
                    "display_name": condition.title(),
                    "confidence": confidence,
                    "source": "LangChain Diagnosis Agent"
                })
        
        return conditions[:5]  # Top 5 conditions
    
    def _extract_recommendations(self, response: str) -> List[str]:
        """Extract treatment recommendations from agent response"""
        # Simple extraction - look for numbered lists or bullet points
        recommendations = []
        
        lines = response.split('\n')
        for line in lines:
            line = line.strip()
            if (line.startswith(('1.', '2.', '3.', '4.', '5.', '-', '•')) or 
                any(keyword in line.lower() for keyword in ['recommend', 'prescribe', 'advise', 'monitor'])):
                # Clean up the line
                clean_line = line.lstrip('1234567890.-• ').strip()
                if clean_line and len(clean_line) > 10:  # Meaningful recommendation
                    recommendations.append(clean_line)
        
        return recommendations[:10]  # Top 10 recommendations
    
    def _calculate_confidence(self, conditions: List[Dict], triage_level: str) -> float:
        """Calculate overall consultation confidence"""
        if not conditions:
            return 0.3
        
        # Base confidence on number and quality of conditions
        avg_confidence = sum(c.get('confidence', 0.5) for c in conditions) / len(conditions)
        
        # Adjust based on triage level certainty
        triage_confidence = {
            "EMERGENCY": 0.9,
            "URGENT": 0.8,
            "LESS_URGENT": 0.7,
            "NON_URGENT": 0.6
        }.get(triage_level, 0.5)
        
        return (avg_confidence + triage_confidence) / 2
    
    def _fallback_consultation(self, patient_data: PatientData) -> ConsultationResult:
        """Fallback consultation when LangChain fails"""
        return ConsultationResult(
            patient_id=patient_data.patient_id,
            timestamp=datetime.now(),
            triage_level="NON_URGENT",
            suspected_conditions=[{
                "name": "general_consultation",
                "display_name": "General Medical Consultation",
                "confidence": 0.5,
                "source": "Fallback System"
            }],
            recommendations=[
                "Consult with healthcare provider for proper evaluation",
                "Monitor symptoms and return if condition worsens",
                "Maintain adequate rest and hydration"
            ],
            referral_needed=False,
            follow_up_required=True,
            confidence_score=0.3,
            reasoning_chain=["Fallback consultation due to system error"],
            evidence_sources=["Basic medical guidelines"]
        )

class MockLLM:
    """Mock LLM for when Ollama is not available"""
    
    def invoke(self, prompt: str) -> str:
        return self._generate_mock_response(prompt)
    
    def __call__(self, prompt: str) -> str:
        return self._generate_mock_response(prompt)
    
    def _generate_mock_response(self, prompt: str) -> str:
        """Generate mock medical response based on prompt content"""
        prompt_lower = prompt.lower()
        
        if "triage" in prompt_lower:
            if any(danger in prompt_lower for danger in ["chest pain", "difficulty breathing", "severe"]):
                return "URGENT: Patient presents with concerning symptoms requiring prompt medical attention."
            else:
                return "NON_URGENT: Patient appears stable with routine medical needs."
        
        elif "diagnosis" in prompt_lower:
            if "fever" in prompt_lower and "headache" in prompt_lower:
                return "Differential diagnosis includes: 1. Malaria (likely) 2. Viral syndrome 3. Bacterial infection"
            elif "cough" in prompt_lower and "fever" in prompt_lower:
                return "Differential diagnosis includes: 1. Pneumonia (likely) 2. Bronchitis 3. Tuberculosis"
            else:
                return "Differential diagnosis requires further clinical evaluation."
        
        elif "treatment" in prompt_lower:
            return """Treatment recommendations:
            1. Symptomatic management with appropriate medications
            2. Monitor vital signs and symptoms
            3. Follow-up in 48-72 hours
            4. Return immediately if symptoms worsen
            5. Maintain adequate hydration and rest"""
        
        return "Medical consultation completed. Please consult with healthcare provider for detailed evaluation."

# Factory function to create the appropriate agent
def create_medical_agent(use_langchain: bool = True, config: Optional[Dict] = None):
    """
    Factory function to create medical agent
    
    Args:
        use_langchain: Whether to use LangChain agent (True) or fallback to custom agent (False)
        config: Configuration dictionary
    
    Returns:
        Medical agent instance
    """
    if use_langchain and FRAMEWORKS_AVAILABLE:
        try:
            return LangChainMedicalAgent(config)
        except Exception as e:
            logger.warning(f"⚠️ LangChain agent failed to initialize: {e}")
            logger.info("🔄 Falling back to custom agent")
    
    # Fallback to custom agent
    from .agent import AfiCareAgent
    from ..utils.config import Config
    
    config_obj = Config() if not config else Config(config)
    return AfiCareAgent(config_obj)