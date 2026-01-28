"""
PWA (Progressive Web App) Component for Streamlit
Enables installable app, offline support, and native-like experience
"""

import streamlit as st
import base64
import os


def get_base64_image(image_path: str) -> str:
    """Convert image to base64 for embedding"""
    if os.path.exists(image_path):
        with open(image_path, "rb") as f:
            return base64.b64encode(f.read()).decode()
    return ""


def inject_pwa_meta_tags():
    """Inject PWA meta tags and manifest link into Streamlit"""

    pwa_meta = """
    <head>
        <!-- PWA Meta Tags -->
        <meta name="application-name" content="AfiCare MediLink">
        <meta name="apple-mobile-web-app-capable" content="yes">
        <meta name="apple-mobile-web-app-status-bar-style" content="default">
        <meta name="apple-mobile-web-app-title" content="AfiCare">
        <meta name="mobile-web-app-capable" content="yes">
        <meta name="theme-color" content="#2E7D32">
        <meta name="msapplication-TileColor" content="#2E7D32">
        <meta name="msapplication-tap-highlight" content="no">

        <!-- Favicon -->
        <link rel="icon" type="image/x-icon" href="/assets/favicon.ico">
        <link rel="icon" type="image/png" sizes="32x32" href="/assets/icon-32x32.png">
        <link rel="icon" type="image/png" sizes="16x16" href="/assets/icon-16x16.png">

        <!-- Apple Touch Icons -->
        <link rel="apple-touch-icon" href="/assets/apple-touch-icon.png">
        <link rel="apple-touch-icon" sizes="152x152" href="/assets/icon-152x152.png">
        <link rel="apple-touch-icon" sizes="180x180" href="/assets/apple-touch-icon.png">
        <link rel="apple-touch-icon" sizes="167x167" href="/assets/icon-152x152.png">

        <!-- Manifest -->
        <link rel="manifest" href="/static/manifest.json">

        <!-- Splash screens for iOS -->
        <meta name="apple-mobile-web-app-capable" content="yes">
    </head>
    """

    st.markdown(pwa_meta, unsafe_allow_html=True)


def inject_service_worker():
    """Inject service worker registration script"""

    sw_script = """
    <script>
        // Register Service Worker for PWA
        if ('serviceWorker' in navigator) {
            window.addEventListener('load', function() {
                navigator.serviceWorker.register('/static/sw.js')
                    .then(function(registration) {
                        console.log('AfiCare SW registered:', registration.scope);
                    })
                    .catch(function(error) {
                        console.log('AfiCare SW registration failed:', error);
                    });
            });
        }

        // Install prompt handling
        let deferredPrompt;
        window.addEventListener('beforeinstallprompt', (e) => {
            e.preventDefault();
            deferredPrompt = e;

            // Show install button if available
            const installBtn = document.getElementById('pwa-install-btn');
            if (installBtn) {
                installBtn.style.display = 'block';
            }
        });

        function installPWA() {
            if (deferredPrompt) {
                deferredPrompt.prompt();
                deferredPrompt.userChoice.then((choiceResult) => {
                    if (choiceResult.outcome === 'accepted') {
                        console.log('User accepted PWA install');
                    }
                    deferredPrompt = null;
                });
            }
        }

        // Check if app is installed
        window.addEventListener('appinstalled', () => {
            console.log('AfiCare MediLink installed successfully');
            deferredPrompt = null;
        });
    </script>
    """

    st.markdown(sw_script, unsafe_allow_html=True)


def display_logo(size: str = "medium"):
    """Display the AfiCare logo

    Args:
        size: "small", "medium", or "large"
    """
    sizes = {
        "small": 60,
        "medium": 100,
        "large": 150
    }
    width = sizes.get(size, 100)

    # Get the assets directory
    script_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    logo_path = os.path.join(script_dir, "assets", "logo.svg")

    if os.path.exists(logo_path):
        with open(logo_path, "r") as f:
            svg_content = f.read()
        st.markdown(
            f'<div style="text-align: center; margin-bottom: 20px;">'
            f'{svg_content}'
            f'</div>',
            unsafe_allow_html=True
        )
    else:
        # Fallback to text logo
        st.markdown(
            f"""
            <div style="text-align: center; margin-bottom: 20px;">
                <h1 style="color: #2E7D32; font-size: {width * 0.4}px; margin: 0;">
                    Afi<span style="color: #1B5E20;">Care</span>
                </h1>
                <p style="color: #666; letter-spacing: 3px; font-size: {width * 0.15}px;">MEDILINK</p>
            </div>
            """,
            unsafe_allow_html=True
        )


def display_icon_logo():
    """Display just the icon portion of the logo"""

    script_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    icon_path = os.path.join(script_dir, "assets", "icon.svg")

    if os.path.exists(icon_path):
        with open(icon_path, "r") as f:
            svg_content = f.read()
        # Resize the SVG
        svg_content = svg_content.replace('viewBox="0 0 512 512"', 'viewBox="0 0 512 512" width="60" height="60"')
        return svg_content
    return ""


def get_header_html():
    """Get the header HTML with logo and title"""

    return """
    <div style="display: flex; align-items: center; gap: 15px; margin-bottom: 20px;">
        <div style="
            width: 50px;
            height: 50px;
            background: linear-gradient(135deg, #2E7D32, #66BB6A);
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 4px 12px rgba(46, 125, 50, 0.3);
        ">
            <span style="color: white; font-size: 24px;">🏥</span>
        </div>
        <div>
            <h1 style="margin: 0; color: #2E7D32; font-size: 28px;">
                Afi<span style="color: #1B5E20;">Care</span> MediLink
            </h1>
            <p style="margin: 0; color: #666; font-size: 12px; letter-spacing: 2px;">
                PATIENT-OWNED HEALTHCARE RECORDS
            </p>
        </div>
    </div>
    """


def inject_mobile_styles():
    """Inject mobile-optimized CSS styles"""

    mobile_css = """
    <style>
        /* Mobile-first responsive design */
        @media (max-width: 768px) {
            .stApp {
                padding: 10px !important;
            }

            .stButton > button {
                width: 100% !important;
                padding: 15px !important;
                font-size: 16px !important;
                border-radius: 12px !important;
            }

            .stTextInput > div > div > input {
                font-size: 16px !important;
                padding: 15px !important;
            }

            .stSelectbox > div > div {
                font-size: 16px !important;
            }

            h1 {
                font-size: 24px !important;
            }

            h2 {
                font-size: 20px !important;
            }

            h3 {
                font-size: 18px !important;
            }
        }

        /* Touch-friendly elements */
        .stButton > button {
            min-height: 48px;
            touch-action: manipulation;
        }

        /* Smooth scrolling */
        html {
            scroll-behavior: smooth;
        }

        /* Better tap highlights */
        * {
            -webkit-tap-highlight-color: rgba(46, 125, 50, 0.2);
        }

        /* Safe area padding for notched phones */
        .stApp {
            padding-left: env(safe-area-inset-left);
            padding-right: env(safe-area-inset-right);
            padding-bottom: env(safe-area-inset-bottom);
        }

        /* Install prompt button */
        #pwa-install-btn {
            display: none;
            position: fixed;
            bottom: 20px;
            right: 20px;
            background: #2E7D32;
            color: white;
            border: none;
            padding: 15px 25px;
            border-radius: 30px;
            font-size: 14px;
            cursor: pointer;
            box-shadow: 0 4px 15px rgba(46, 125, 50, 0.4);
            z-index: 9999;
            animation: pulse 2s infinite;
        }

        @keyframes pulse {
            0% { transform: scale(1); }
            50% { transform: scale(1.05); }
            100% { transform: scale(1); }
        }

        #pwa-install-btn:hover {
            background: #1B5E20;
        }

        /* Loading spinner for offline indicator */
        .offline-indicator {
            position: fixed;
            top: 10px;
            right: 10px;
            background: #FF9800;
            color: white;
            padding: 8px 15px;
            border-radius: 20px;
            font-size: 12px;
            z-index: 9999;
            display: none;
        }

        .offline-indicator.show {
            display: block;
        }
    </style>

    <!-- Install button and offline indicator -->
    <button id="pwa-install-btn" onclick="installPWA()">
        📲 Install App
    </button>

    <div class="offline-indicator" id="offline-indicator">
        📡 Offline Mode
    </div>

    <script>
        // Show offline indicator when offline
        window.addEventListener('offline', () => {
            document.getElementById('offline-indicator').classList.add('show');
        });
        window.addEventListener('online', () => {
            document.getElementById('offline-indicator').classList.remove('show');
        });
        if (!navigator.onLine) {
            document.getElementById('offline-indicator').classList.add('show');
        }
    </script>
    """

    st.markdown(mobile_css, unsafe_allow_html=True)


def init_pwa():
    """Initialize all PWA features - call this at the start of your Streamlit app"""
    inject_pwa_meta_tags()
    inject_service_worker()
    inject_mobile_styles()


def show_install_instructions():
    """Show PWA installation instructions for users"""

    with st.expander("📲 Install AfiCare App on Your Device"):
        st.markdown("""
        ### Install on Android
        1. Open this page in Chrome
        2. Tap the menu (⋮) in the top right
        3. Tap "Add to Home screen"
        4. Tap "Add"

        ### Install on iPhone/iPad
        1. Open this page in Safari
        2. Tap the Share button (□↑)
        3. Scroll down and tap "Add to Home Screen"
        4. Tap "Add"

        ### Install on Desktop (Chrome/Edge)
        1. Look for the install icon (⊕) in the address bar
        2. Click "Install"

        ---
        Once installed, AfiCare will work like a native app with:
        - ✅ Offline access to cached data
        - ✅ Full-screen experience
        - ✅ Quick launch from home screen
        - ✅ Push notifications (coming soon)
        """)
