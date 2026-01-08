# AfiCare Medical Agent

An AI-powered medical assistant designed for healthcare settings in Africa, providing evidence-based diagnostic support and treatment recommendations for common conditions.

## 🏥 Overview

AfiCare is a comprehensive medical AI system that combines rule-based medical knowledge with local LLM capabilities to assist healthcare workers in resource-limited settings. The system focuses on conditions prevalent in African healthcare contexts while maintaining cultural sensitivity and practical applicability.

## ✨ Key Features

### 🧠 Medical Intelligence
- **Local LLM Integration**: Offline-capable Llama 3.2 3B model for medical reasoning
- **Rule-Based Engine**: Evidence-based diagnostic rules for common conditions
- **Triage System**: Automated patient prioritization and urgency assessment
- **Differential Diagnosis**: AI-assisted diagnostic suggestions

### 🌍 Localization & Accessibility
- **Multi-language Support**: English, Kiswahili, and Luganda
- **Cultural Adaptation**: Contextually appropriate for African healthcare settings
- **Offline Operation**: Works without internet connectivity
- **Resource-Aware**: Designed for limited-resource environments

### 📊 Medical Knowledge Base
- **Common Conditions**: Malaria, pneumonia, tuberculosis, hypertension, diabetes
- **Treatment Protocols**: WHO IMCI guidelines and local treatment standards
- **Medication Formulary**: Regional medication availability and dosing
- **Patient Education**: Multi-language health education materials

### 🔧 Technical Capabilities
- **RESTful API**: FastAPI-based backend for integration
- **Web Interface**: Streamlit-based user interface
- **Database Management**: Patient records and consultation history
- **Security**: Encrypted data storage and secure authentication

## 🚀 Quick Start

### Prerequisites
- Python 3.9 or higher
- 4GB+ RAM (8GB recommended for LLM)
- 2GB+ storage space

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/aficare/aficare-agent.git
   cd aficare-agent
   ```

2. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Download the LLM model** (optional for full functionality)
   ```bash
   # Download Llama 3.2 3B model to data/models/
   # Model file: llama-3.2-3b-instruct.Q4_K_M.gguf
   ```

4. **Configure the system**
   ```bash
   # Edit config/default.yaml for your environment
   # Update database URL, model paths, etc.
   ```

5. **Run the application**
   ```bash
   python run.py --mode both
   ```

### Access Points
- **Web UI**: http://localhost:8501
- **API Documentation**: http://localhost:8000/docs
- **Health Check**: http://localhost:8000/health

## 📖 Usage

### Basic Consultation Workflow

1. **Patient Registration**: Enter patient demographics and basic information
2. **Symptom Assessment**: Record presenting symptoms and vital signs
3. **AI Analysis**: System provides diagnostic suggestions and triage level
4. **Treatment Planning**: Receive evidence-based treatment recommendations
5. **Patient Education**: Generate culturally appropriate education materials
6. **Follow-up Scheduling**: Set appropriate follow-up intervals

### API Usage Example

```python
import requests

# Start a consultation
consultation_data = {
    "patient_id": "AFC-2024-00001",
    "age": 25,
    "gender": "female",
    "symptoms": ["fever", "headache", "chills"],
    "vital_signs": {
        "temperature": 39.2,
        "blood_pressure": "120/80",
        "pulse": 95
    },
    "chief_complaint": "Fever and headache for 2 days"
}

response = requests.post(
    "http://localhost:8000/api/consultations",
    json=consultation_data
)

result = response.json()
print(f"Triage Level: {result['triage_level']}")
print(f"Suspected Conditions: {result['suspected_conditions']}")
```

## 🏗️ Architecture

### Core Components

- **Agent Core** (`src/core/`): Main medical reasoning engine
- **LLM Integration** (`src/llm/`): Local language model interface
- **Rule Engine** (`src/rules/`): Medical knowledge and diagnostic rules
- **Memory System** (`src/memory/`): Patient data and consultation storage
- **API Layer** (`src/api/`): RESTful web services
- **UI Components** (`src/ui/`): Web-based user interface

### Data Flow

```
Patient Input → Symptom Analysis → Rule Engine → LLM Reasoning → 
Diagnostic Output → Treatment Recommendations → Patient Education
```

## 🔧 Configuration

### Environment Variables
```bash
AFICARE_DB_URL=sqlite:///./aficare.db
AFICARE_LLM_MODEL_PATH=./data/models/llama-3.2-3b-instruct.Q4_K_M.gguf
AFICARE_API_HOST=0.0.0.0
AFICARE_API_PORT=8000
AFICARE_SECRET_KEY=your-secret-key
AFICARE_LOG_LEVEL=INFO
```

### Configuration Files
- `config/default.yaml`: Main application configuration
- `config/clinic_config.yaml`: Clinic-specific settings
- `config/languages.yaml`: Multi-language support configuration

## 📚 Medical Knowledge

### Supported Conditions
- **Infectious Diseases**: Malaria, pneumonia, tuberculosis
- **Chronic Conditions**: Hypertension, diabetes
- **Maternal Health**: Antenatal care protocols
- **Pediatric Care**: Childhood diarrhea, IMCI guidelines

### Treatment Protocols
- WHO Integrated Management of Childhood Illness (IMCI)
- Kenya Ministry of Health guidelines
- Evidence-based treatment algorithms
- Local medication formularies

## 🛡️ Security & Privacy

- **Data Encryption**: All patient data encrypted at rest
- **Access Control**: Role-based authentication system
- **Audit Logging**: Comprehensive medical event logging
- **HIPAA Compliance**: Privacy-focused design principles
- **Offline Operation**: No data transmission to external servers

## 🧪 Development

### Running Tests
```bash
# Unit tests
python -m pytest tests/unit/

# Integration tests
python -m pytest tests/integration/

# All tests with coverage
python -m pytest --cov=src tests/
```

### Development Setup
```bash
# Install development dependencies
pip install -r requirements-dev.txt

# Setup pre-commit hooks
pre-commit install

# Run code formatting
black src/
isort src/

# Type checking
mypy src/
```

## 📦 Deployment

### Docker Deployment
```bash
# Build image
docker build -t aficare-agent .

# Run container
docker run -p 8000:8000 -p 8501:8501 aficare-agent
```

### Production Considerations
- Use PostgreSQL for production database
- Configure proper SSL certificates
- Set up monitoring and alerting
- Regular database backups
- Load balancing for high availability

## 🤝 Contributing

We welcome contributions to improve AfiCare! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Areas for Contribution
- Additional medical conditions and protocols
- Language translations and cultural adaptations
- UI/UX improvements
- Performance optimizations
- Documentation and tutorials

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- World Health Organization for IMCI guidelines
- African medical communities for clinical insights
- Open-source medical knowledge initiatives
- Llama.cpp community for local LLM support

## 📞 Support

- **Documentation**: [docs.aficare.org](https://docs.aficare.org)
- **Issues**: [GitHub Issues](https://github.com/aficare/aficare-agent/issues)
- **Discussions**: [GitHub Discussions](https://github.com/aficare/aficare-agent/discussions)
- **Email**: support@aficare.org

---

**⚠️ Medical Disclaimer**: AfiCare is a clinical decision support tool and should not replace professional medical judgment. Always consult qualified healthcare providers for medical decisions.