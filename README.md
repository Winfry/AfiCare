# AfiCare - AI-Powered Medical Assistant

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.8+](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/downloads/)

AfiCare is an AI-powered medical assistant designed to support healthcare providers in resource-constrained environments, particularly in African healthcare settings. It provides offline-capable medical decision support, patient management, and clinical guidance.

## 🌟 Features

- **Offline AI Medical Assistant**: Local LLM for medical consultations without internet
- **Multi-language Support**: English, Swahili, Luganda
- **Clinical Decision Support**: WHO IMCI guidelines, Kenya MOH protocols
- **Patient Management**: Complete patient records and visit tracking
- **Triage System**: Automated patient prioritization
- **Knowledge Base**: Comprehensive medical conditions and treatments
- **Cross-platform**: Windows, macOS, Linux support

## 🚀 Quick Start

### Prerequisites
- Python 3.8 or higher
- 4GB+ RAM (8GB recommended for LLM)
- 10GB+ storage space

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-org/aficare.git
cd aficare
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set up the local LLM:
```bash
python scripts/setup_ollama.py
```

4. Import sample data:
```bash
python scripts/import_sample_data.py
```

5. Run the application:
```bash
python run.py
```

## 📖 Documentation

- [Installation Guide](docs/installation.md)
- [User Guide](docs/user_guide.md)
- [Developer Guide](docs/developer_guide.md)
- [API Reference](docs/api_reference.md)
- [Medical Rules](docs/medical_rules.md)

## 🏗️ Architecture

AfiCare follows a modular architecture:

- **Core Agent**: Main reasoning and decision engine
- **LLM Integration**: Local language model for medical queries
- **Memory System**: Patient data and visit management
- **Rules Engine**: Medical protocols and guidelines
- **UI Layer**: User interface for healthcare providers
- **API Layer**: RESTful endpoints for integration

## 🌍 Supported Conditions

- Malaria
- Pneumonia
- Tuberculosis
- Hypertension
- Diabetes
- Antenatal Care
- Childhood Diarrhea
- And more...

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Medical Disclaimer

AfiCare is designed to assist healthcare providers and should not replace professional medical judgment. Always consult with qualified healthcare professionals for medical decisions.         

