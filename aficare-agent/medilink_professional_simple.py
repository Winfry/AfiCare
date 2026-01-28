"""
MediLink Professional Simple - Beautiful medical application without complex dependencies
Cost-free deployment with stunning visuals and professional UX
"""

import streamlit as st
from datetime import datetime, timedelta
import secrets
import json
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple

# Import basic components
import sys
sys.path.append(str(Path(__file__).parent))

try:
    from src.database.database_manager import DatabaseManager
    from medilink_simple import (
        PatientData, ConsultationResult, SimpleRuleEngine, 
        SimpleTriageEngine, MedicalAI, generate_medilink_id
    )
    IMPORTS_SUCCESS = True
except Exception as e:
    IMPORTS_SUCCESS = False
    import_error = str(e)

# Page configuration
st.set_page_config(
    page_title="AfiCare MediLink Professional",
    page_icon="🏥",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Professional Medical Theme CSS (embedded)
st.markdown("""
<style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
    
    :root {
        --primary-color: #2563eb;
        --primary-dark: #1d4ed8;
        --secondary-color: #10b981;
        --accent-color: #f59e0b;
        --danger-color: #ef4444;
        --warning-color: #f97316;
        --success-color: #22c55e;
        --info-color: #3b82f6;
        
        --bg-primary: #ffffff;
        --bg-secondary: #f8fafc;
        --bg-tertiary: #f1f5f9;
        --text-primary: #1e293b;
        --text-secondary: #64748b;
        --text-muted: #94a3b8;
        
        --border-color: #e2e8f0;
        --shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.05);
        --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.1);
        --shadow-lg: 0 10px 15px -3px rgb(0 0 0 / 0.1);
        
   