#!/bin/bash
# create_aficare_structure.sh - Creates the complete directory structure for AfiCare Agent

echo "📁 Creating AfiCare Agent Project Structure..."

# Create main directory
mkdir -p aficare-agent
cd aficare-agent

# Create .github workflows
mkdir -p .github/workflows
touch .github/workflows/tests.yml

# Create data directory structure
mkdir -p data/knowledge_base/conditions
mkdir -p data/knowledge_base/medications
mkdir -p data/knowledge_base/guidelines
mkdir -p data/knowledge_base/translations
mkdir -p data/models
mkdir -p data/sample_data

# Create empty files in knowledge_base/conditions
touch data/knowledge_base/conditions/malaria.json
touch data/knowledge_base/conditions/pneumonia.json
touch data/knowledge_base/conditions/tuberculosis.json
touch data/knowledge_base/conditions/hypertension.json
touch data/knowledge_base/conditions/diabetes.json
touch data/knowledge_base/conditions/antenatal_care.json
touch data/knowledge_base/conditions/childhood_diarrhea.json

# Create empty files in knowledge_base/medications
touch data/knowledge_base/medications/formulary_ke.json
touch data/knowledge_base/medications/interactions.json
touch data/knowledge_base/medications/dosages.json

# Create empty files in knowledge_base/guidelines
touch data/knowledge_base/guidelines/who_imci.json
touch data/knowledge_base/guidelines/kenya_moh.json
touch data/knowledge_base/guidelines/hiv_tb.json

# Create empty files in knowledge_base/translations
touch data/knowledge_base/translations/en.json
touch data/knowledge_base/translations/sw.json
touch data/knowledge_base/translations/lg.json

# Create empty model file (placeholder)
touch data/models/llama-3.2-3b-instruct.Q4_K_M.gguf

# Create empty sample data files
touch data/sample_data/patients.csv
touch data/sample_data/visits_sample.json

# Create src directory structure
mkdir -p src/core
mkdir -p src/memory
mkdir -p src/llm
mkdir -p src/rules
mkdir -p src/ui/components
mkdir -p src/ui/themes
mkdir -p src/utils
mkdir -p src/api/endpoints

# Create empty Python files in src/core
touch src/core/__init__.py
touch src/core/agent.py
touch src/core/reasoning_engine.py
touch src/core/context_manager.py
touch src/core/decision_planner.py

# Create empty Python files in src/memory
touch src/memory/__init__.py
touch src/memory/database.py
touch src/memory/patient_store.py
touch src/memory/visit_manager.py
touch src/memory/alert_system.py

# Create empty Python files in src/llm
touch src/llm/__init__.py
touch src/llm/local_llm.py
touch src/llm/prompt_templates.py
touch src/llm/response_parser.py

# Create empty Python files in src/rules
touch src/rules/__init__.py
touch src/rules/rule_engine.py
touch src/rules/symptom_analyzer.py
touch src/rules/triage_engine.py
touch src/rules/condition_matcher.py

# Create empty Python files in src/ui
touch src/ui/__init__.py
touch src/ui/app.py
touch src/ui/components/patient_form.py
touch src/ui/components/symptom_input.py
touch src/ui/components/consultation_view.py
touch src/ui/components/patient_history.py
touch src/ui/themes/clinic_theme.py

# Create empty Python files in src/utils
touch src/utils/__init__.py
touch src/utils/config.py
touch src/utils/logger.py
touch src/utils/security.py
touch src/utils/backup.py
touch src/utils/validators.py

# Create empty Python files in src/api
touch src/api/__init__.py
touch src/api/main.py
touch src/api/endpoints/patients.py
touch src/api/endpoints/consultations.py
touch src/api/endpoints/agent.py

# Create tests directory structure
mkdir -p tests/unit
mkdir -p tests/integration
mkdir -p tests/data

# Create empty test files
touch tests/unit/test_agent.py
touch tests/unit/test_rules.py
touch tests/unit/test_memory.py
touch tests/integration/test_consultation_flow.py
touch tests/integration/test_offline_sync.py
touch tests/data/test_patients.json

# Create deployments directory structure
mkdir -p deployments/windows
mkdir -p deployments/macos
mkdir -p deployments/linux
mkdir -p deployments/docker

# Create empty deployment files
touch deployments/windows/build_exe.ps1
touch deployments/windows/installer.nsi
touch deployments/macos/build_dmg.sh
touch deployments/linux/build_deb.sh
touch deployments/docker/Dockerfile

# Create docs directory
mkdir -p docs

# Create empty documentation files
touch docs/architecture.md
touch docs/installation.md
touch docs/user_guide.md
touch docs/developer_guide.md
touch docs/medical_rules.md
touch docs/api_reference.md

# Create scripts directory
mkdir -p scripts

# Create empty script files
touch scripts/setup_ollama.py
touch scripts/import_sample_data.py
touch scripts/backup_database.py
touch scripts/export_patient_data.py

# Create config directory
mkdir -p config

# Create empty config files
touch config/default.yaml
touch config/clinic_config.yaml
touch config/languages.yaml

# Create root project files
touch requirements.txt
touch requirements-dev.txt
touch pyproject.toml
touch README.md
touch LICENSE
touch .env.example
touch .gitignore
touch run.py

echo "✅ Project structure created successfully!"
echo "📊 Directory structure summary:"
echo ""
echo "aficare-agent/"
echo "├── .github/workflows/tests.yml"
echo "├── data/"
echo "│   ├── knowledge_base/conditions/*.json (7 files)"
echo "│   ├── knowledge_base/medications/*.json (3 files)"
echo "│   ├── knowledge_base/guidelines/*.json (3 files)"
echo "│   ├── knowledge_base/translations/*.json (3 files)"
echo "│   ├── models/llama-3.2-3b-instruct.Q4_K_M.gguf"
echo "│   └── sample_data/patients.csv, visits_sample.json"
echo "├── src/"
echo "│   ├── core/*.py (5 files)"
echo "│   ├── memory/*.py (5 files)"
echo "│   ├── llm/*.py (4 files)"
echo "│   ├── rules/*.py (5 files)"
echo "│   ├── ui/app.py, components/*.py (5 files), themes/*.py"
echo "│   ├── utils/*.py (6 files)"
echo "│   └── api/main.py, endpoints/*.py (4 files)"
echo "├── tests/"
echo "│   ├── unit/*.py (3 files)"
echo "│   ├── integration/*.py (2 files)"
echo "│   └── data/test_patients.json"
echo "├── deployments/"
echo "│   ├── windows/*.ps1, *.nsi"
echo "│   ├── macos/*.sh"
echo "│   ├── linux/*.sh"
echo "│   └── docker/Dockerfile"
echo "├── docs/*.md (6 files)"
echo "├── scripts/*.py (4 files)"
echo "├── config/*.yaml (3 files)"
echo "└── root files (8 files)"
echo ""
echo "Total directories created: $(find . -type d | wc -l)"
echo "Total empty files created: $(find . -type f | wc -l)"
echo ""
echo "To run this script:"
echo "1. Save as create_structure.sh"
echo "2. Make executable: chmod +x create_structure.sh"
echo "3. Run: ./create_structure.sh"