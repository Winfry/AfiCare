"""
Professional Medical Theme for AfiCare MediLink
Beautiful, modern styling for healthcare applications
"""

def get_professional_medical_css():
    """Get professional medical CSS styling"""
    
    return """
    <style>
    /* Import Google Fonts */
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
    @import url('https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700&display=swap');
    
    /* Root Variables */
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
        
        --radius-sm: 0.375rem;
        --radius-md: 0.5rem;
        --radius-lg: 0.75rem;
        --radius-xl: 1rem;
    }
    
    /* Dark Mode Variables */
    [data-theme="dark"] {
        --bg-primary: #0f172a;
        --bg-secondary: #1e293b;
        --bg-tertiary: #334155;
        --text-primary: #f1f5f9;
        --text-secondary: #cbd5e1;
        --text-muted: #64748b;
        --border-color: #334155;
    }
    
    /* Global Styles */
    .stApp {
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        min-height: 100vh;
    }
    
    .main .block-container {
        padding-top: 2rem;
        padding-bottom: 2rem;
        max-width: 1200px;
    }
    
    /* Header Styles */
    .medical-header {
        background: linear-gradient(135deg, var(--primary-color) 0%, var(--primary-dark) 100%);
        padding: 2rem;
        border-radius: var(--radius-xl);
        color: white;
        text-align: center;
        margin-bottom: 2rem;
        box-shadow: var(--shadow-lg);
        position: relative;
        overflow: hidden;
    }
    
    .medical-header::before {
        content: '';
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><pattern id="grid" width="10" height="10" patternUnits="userSpaceOnUse"><path d="M 10 0 L 0 0 0 10" fill="none" stroke="rgba(255,255,255,0.1)" stroke-width="0.5"/></pattern></defs><rect width="100" height="100" fill="url(%23grid)"/></svg>');
        opacity: 0.3;
    }
    
    .medical-header h1 {
        font-size: 2.5rem;
        font-weight: 700;
        margin: 0;
        position: relative;
        z-index: 1;
    }
    
    .medical-header p {
        font-size: 1.1rem;
        margin: 0.5rem 0 0 0;
        opacity: 0.9;
        position: relative;
        z-index: 1;
    }
    
    /* Card Styles */
    .medical-card {
        background: var(--bg-primary);
        border-radius: var(--radius-lg);
        padding: 1.5rem;
        margin: 1rem 0;
        box-shadow: var(--shadow-md);
        border: 1px solid var(--border-color);
        transition: all 0.3s ease;
    }
    
    .medical-card:hover {
        transform: translateY(-2px);
        box-shadow: var(--shadow-lg);
    }
    
    .medical-card-header {
        display: flex;
        align-items: center;
        margin-bottom: 1rem;
        padding-bottom: 0.75rem;
        border-bottom: 2px solid var(--border-color);
    }
    
    .medical-card-icon {
        width: 2.5rem;
        height: 2.5rem;
        border-radius: var(--radius-md);
        display: flex;
        align-items: center;
        justify-content: center;
        margin-right: 1rem;
        font-size: 1.25rem;
    }
    
    .medical-card-title {
        font-size: 1.25rem;
        font-weight: 600;
        color: var(--text-primary);
        margin: 0;
    }
    
    /* Status Cards */
    .status-card {
        background: var(--bg-primary);
        border-radius: var(--radius-lg);
        padding: 1.5rem;
        text-align: center;
        box-shadow: var(--shadow-md);
        border-left: 4px solid var(--primary-color);
        transition: all 0.3s ease;
    }
    
    .status-card:hover {
        transform: translateY(-2px);
        box-shadow: var(--shadow-lg);
    }
    
    .status-card.success {
        border-left-color: var(--success-color);
    }
    
    .status-card.warning {
        border-left-color: var(--warning-color);
    }
    
    .status-card.danger {
        border-left-color: var(--danger-color);
    }
    
    .status-card.info {
        border-left-color: var(--info-color);
    }
    
    .status-number {
        font-size: 2rem;
        font-weight: 700;
        color: var(--primary-color);
        margin-bottom: 0.5rem;
    }
    
    .status-label {
        font-size: 0.875rem;
        color: var(--text-secondary);
        font-weight: 500;
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }
    
    /* Button Styles */
    .stButton > button {
        background: linear-gradient(135deg, var(--primary-color) 0%, var(--primary-dark) 100%);
        color: white;
        border: none;
        border-radius: var(--radius-md);
        padding: 0.75rem 1.5rem;
        font-weight: 500;
        font-size: 0.875rem;
        transition: all 0.3s ease;
        box-shadow: var(--shadow-sm);
    }
    
    .stButton > button:hover {
        transform: translateY(-1px);
        box-shadow: var(--shadow-md);
        background: linear-gradient(135deg, var(--primary-dark) 0%, var(--primary-color) 100%);
    }
    
    .stButton > button:active {
        transform: translateY(0);
    }
    
    /* Success Button */
    .stButton.success > button {
        background: linear-gradient(135deg, var(--success-color) 0%, #16a34a 100%);
    }
    
    /* Warning Button */
    .stButton.warning > button {
        background: linear-gradient(135deg, var(--warning-color) 0%, #ea580c 100%);
    }
    
    /* Danger Button */
    .stButton.danger > button {
        background: linear-gradient(135deg, var(--danger-color) 0%, #dc2626 100%);
    }
    
    /* Form Styles */
    .stTextInput > div > div > input {
        border-radius: var(--radius-md);
        border: 2px solid var(--border-color);
        padding: 0.75rem;
        font-size: 0.875rem;
        transition: all 0.3s ease;
    }
    
    .stTextInput > div > div > input:focus {
        border-color: var(--primary-color);
        box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1);
    }
    
    .stSelectbox > div > div > select {
        border-radius: var(--radius-md);
        border: 2px solid var(--border-color);
        padding: 0.75rem;
    }
    
    .stTextArea > div > div > textarea {
        border-radius: var(--radius-md);
        border: 2px solid var(--border-color);
        padding: 0.75rem;
        font-family: inherit;
    }
    
    /* Sidebar Styles */
    .css-1d391kg {
        background: var(--bg-secondary);
        border-right: 1px solid var(--border-color);
    }
    
    .css-1d391kg .css-1v0mbdj {
        border-radius: var(--radius-md);
        margin-bottom: 1rem;
    }
    
    /* Tabs */
    .stTabs [data-baseweb="tab-list"] {
        gap: 0.5rem;
        background: var(--bg-secondary);
        padding: 0.5rem;
        border-radius: var(--radius-lg);
    }
    
    .stTabs [data-baseweb="tab"] {
        background: transparent;
        border-radius: var(--radius-md);
        padding: 0.75rem 1.5rem;
        font-weight: 500;
        transition: all 0.3s ease;
    }
    
    .stTabs [aria-selected="true"] {
        background: var(--primary-color);
        color: white;
    }
    
    /* Metrics */
    .css-1xarl3l {
        background: var(--bg-primary);
        border-radius: var(--radius-lg);
        padding: 1rem;
        border: 1px solid var(--border-color);
        box-shadow: var(--shadow-sm);
    }
    
    /* Expander */
    .streamlit-expanderHeader {
        background: var(--bg-secondary);
        border-radius: var(--radius-md);
        padding: 0.75rem;
        border: 1px solid var(--border-color);
    }
    
    /* Alert Styles */
    .alert {
        padding: 1rem;
        border-radius: var(--radius-md);
        margin: 1rem 0;
        border-left: 4px solid;
        font-weight: 500;
    }
    
    .alert.success {
        background: #f0fdf4;
        border-left-color: var(--success-color);
        color: #166534;
    }
    
    .alert.warning {
        background: #fffbeb;
        border-left-color: var(--warning-color);
        color: #92400e;
    }
    
    .alert.danger {
        background: #fef2f2;
        border-left-color: var(--danger-color);
        color: #991b1b;
    }
    
    .alert.info {
        background: #eff6ff;
        border-left-color: var(--info-color);
        color: #1e40af;
    }
    
    /* QR Code Container */
    .qr-code-container {
        background: var(--bg-primary);
        border-radius: var(--radius-xl);
        padding: 2rem;
        text-align: center;
        box-shadow: var(--shadow-lg);
        border: 2px solid var(--border-color);
        margin: 1rem 0;
    }
    
    .qr-code-container img {
        border-radius: var(--radius-md);
        box-shadow: var(--shadow-md);
    }
    
    /* Access Code Display */
    .access-code-display {
        background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%);
        border: 2px solid var(--info-color);
        border-radius: var(--radius-xl);
        padding: 2rem;
        text-align: center;
        margin: 1rem 0;
        position: relative;
        overflow: hidden;
    }
    
    .access-code-display::before {
        content: '';
        position: absolute;
        top: -50%;
        left: -50%;
        width: 200%;
        height: 200%;
        background: radial-gradient(circle, rgba(59, 130, 246, 0.1) 0%, transparent 70%);
        animation: pulse 3s ease-in-out infinite;
    }
    
    @keyframes pulse {
        0%, 100% { transform: scale(1); opacity: 0.5; }
        50% { transform: scale(1.1); opacity: 0.8; }
    }
    
    .access-code-number {
        font-size: 3rem;
        font-weight: 700;
        color: var(--info-color);
        font-family: 'Roboto Mono', monospace;
        letter-spacing: 0.2em;
        text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        position: relative;
        z-index: 1;
    }
    
    /* Audit Log Entry */
    .audit-log-entry {
        background: var(--bg-primary);
        border-left: 4px solid var(--info-color);
        border-radius: var(--radius-md);
        padding: 1rem;
        margin: 0.5rem 0;
        box-shadow: var(--shadow-sm);
        transition: all 0.3s ease;
    }
    
    .audit-log-entry:hover {
        transform: translateX(4px);
        box-shadow: var(--shadow-md);
    }
    
    .audit-log-entry.success {
        border-left-color: var(--success-color);
    }
    
    .audit-log-entry.warning {
        border-left-color: var(--warning-color);
    }
    
    .audit-log-entry.danger {
        border-left-color: var(--danger-color);
    }
    
    /* Loading Animation */
    .loading-spinner {
        display: inline-block;
        width: 20px;
        height: 20px;
        border: 3px solid rgba(37, 99, 235, 0.3);
        border-radius: 50%;
        border-top-color: var(--primary-color);
        animation: spin 1s ease-in-out infinite;
    }
    
    @keyframes spin {
        to { transform: rotate(360deg); }
    }
    
    /* Responsive Design */
    @media (max-width: 768px) {
        .main .block-container {
            padding-left: 1rem;
            padding-right: 1rem;
        }
        
        .medical-header h1 {
            font-size: 2rem;
        }
        
        .medical-card {
            padding: 1rem;
        }
        
        .access-code-number {
            font-size: 2rem;
        }
    }
    
    /* Smooth Transitions */
    * {
        transition: color 0.3s ease, background-color 0.3s ease, border-color 0.3s ease;
    }
    
    /* Hide Streamlit Branding */
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
    header {visibility: hidden;}
    
    /* Custom Scrollbar */
    ::-webkit-scrollbar {
        width: 8px;
    }
    
    ::-webkit-scrollbar-track {
        background: var(--bg-secondary);
    }
    
    ::-webkit-scrollbar-thumb {
        background: var(--border-color);
        border-radius: var(--radius-sm);
    }
    
    ::-webkit-scrollbar-thumb:hover {
        background: var(--text-muted);
    }
    </style>
    """

def get_medical_icons():
    """Get medical icon mappings"""
    
    return {
        'patient': '👤',
        'doctor': '👨‍⚕️',
        'nurse': '👩‍⚕️',
        'admin': '⚙️',
        'consultation': '🩺',
        'access_code': '🔑',
        'qr_code': '📱',
        'export': '📄',
        'audit': '📊',
        'profile': '👤',
        'emergency': '🚨',
        'warning': '⚠️',
        'success': '✅',
        'info': 'ℹ️',
        'heart': '❤️',
        'temperature': '🌡️',
        'blood_pressure': '🩸',
        'medication': '💊',
        'hospital': '🏥',
        'ambulance': '🚑',
        'stethoscope': '🩺',
        'syringe': '💉',
        'bandage': '🩹',
        'microscope': '🔬',
        'x_ray': '🦴',
        'calendar': '📅',
        'clock': '🕐',
        'phone': '📞',
        'email': '📧',
        'location': '📍',
        'shield': '🛡️',
        'lock': '🔒',
        'key': '🔑',
        'chart': '📈',
        'report': '📋',
        'download': '⬇️',
        'upload': '⬆️',
        'search': '🔍',
        'filter': '🔽',
        'settings': '⚙️',
        'help': '❓',
        'star': '⭐',
        'bookmark': '🔖',
        'flag': '🚩',
        'bell': '🔔',
        'message': '💬',
        'mail': '✉️',
        'globe': '🌍',
        'wifi': '📶',
        'battery': '🔋',
        'power': '⚡',
        'refresh': '🔄',
        'sync': '🔄',
        'backup': '💾',
        'cloud': '☁️',
        'database': '🗄️',
        'server': '🖥️',
        'mobile': '📱',
        'tablet': '📱',
        'laptop': '💻',
        'desktop': '🖥️',
        'printer': '🖨️',
        'scanner': '📷',
        'camera': '📸',
        'video': '📹',
        'microphone': '🎤',
        'speaker': '🔊',
        'headphones': '🎧'
    }

def apply_medical_theme():
    """Apply the professional medical theme to Streamlit"""
    
    import streamlit as st
    
    # Apply CSS
    st.markdown(get_professional_medical_css(), unsafe_allow_html=True)
    
    # Add theme toggle (future enhancement)
    # st.markdown("""
    # <script>
    # function toggleTheme() {
    #     document.documentElement.setAttribute('data-theme', 
    #         document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark'
    #     );
    # }
    # </script>
    # """, unsafe_allow_html=True)

def create_medical_header(title: str, subtitle: str, icon: str = "🏥"):
    """Create a professional medical header"""
    
    import streamlit as st
    
    st.markdown(f"""
    <div class="medical-header">
        <h1>{icon} {title}</h1>
        <p>{subtitle}</p>
    </div>
    """, unsafe_allow_html=True)

def create_status_card(number: str, label: str, card_type: str = "info"):
    """Create a status card with number and label"""
    
    import streamlit as st
    
    st.markdown(f"""
    <div class="status-card {card_type}">
        <div class="status-number">{number}</div>
        <div class="status-label">{label}</div>
    </div>
    """, unsafe_allow_html=True)

def create_medical_card(title: str, content: str, icon: str = "ℹ️"):
    """Create a medical information card"""
    
    import streamlit as st
    
    st.markdown(f"""
    <div class="medical-card">
        <div class="medical-card-header">
            <div class="medical-card-icon">{icon}</div>
            <h3 class="medical-card-title">{title}</h3>
        </div>
        <div class="medical-card-content">
            {content}
        </div>
    </div>
    """, unsafe_allow_html=True)

def create_alert(message: str, alert_type: str = "info"):
    """Create a styled alert message"""
    
    import streamlit as st
    
    st.markdown(f"""
    <div class="alert {alert_type}">
        {message}
    </div>
    """, unsafe_allow_html=True)

def create_access_code_display(code: str, expires: str):
    """Create a beautiful access code display"""
    
    import streamlit as st
    
    st.markdown(f"""
    <div class="access-code-display">
        <h3>🎯 Your Access Code</h3>
        <div class="access-code-number">{code}</div>
        <p>Expires: {expires}</p>
    </div>
    """, unsafe_allow_html=True)

def create_audit_log_entry(user: str, action: str, time: str, success: bool = True):
    """Create a styled audit log entry"""
    
    import streamlit as st
    
    entry_type = "success" if success else "danger"
    icon = "✅" if success else "❌"
    
    st.markdown(f"""
    <div class="audit-log-entry {entry_type}">
        <strong>{icon} {user}</strong> - {action}<br>
        <small>📅 {time}</small>
    </div>
    """, unsafe_allow_html=True)