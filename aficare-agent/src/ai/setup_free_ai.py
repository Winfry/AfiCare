"""
Setup FREE AI Backends for AfiCare

This script helps you set up FREE AI capabilities:
1. Groq Cloud (30 req/min FREE)
2. Ollama (Local, unlimited, FREE)
3. Google AI (60 req/min FREE)
"""

import os
import subprocess
import sys

def print_header(text):
    print("\n" + "=" * 50)
    print(f" {text}")
    print("=" * 50)

def check_groq():
    """Check and setup Groq (FREE cloud AI)"""
    print_header("GROQ SETUP (FREE - 30 req/min)")

    api_key = os.getenv("GROQ_API_KEY")

    if api_key:
        print("[OK] GROQ_API_KEY found in environment")
        return True

    print("""
To get FREE Groq API access:

1. Go to: https://console.groq.com
2. Sign up (FREE)
3. Go to API Keys
4. Create new key
5. Set environment variable:

   Windows (PowerShell):
   $env:GROQ_API_KEY = "your-key-here"

   Windows (permanently):
   setx GROQ_API_KEY "your-key-here"

   Linux/Mac:
   export GROQ_API_KEY="your-key-here"

FREE Tier: 30 requests/minute (more than enough!)
Models: Llama 3, Mixtral, Gemma (all FREE)
""")

    return False

def check_ollama():
    """Check and setup Ollama (FREE local AI)"""
    print_header("OLLAMA SETUP (FREE - Local, Unlimited)")

    try:
        result = subprocess.run(
            ["ollama", "--version"],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            print(f"[OK] Ollama installed: {result.stdout.strip()}")

            # Check for models
            models = subprocess.run(
                ["ollama", "list"],
                capture_output=True,
                text=True
            )
            print(f"\nInstalled models:\n{models.stdout}")
            return True
    except FileNotFoundError:
        pass

    print("""
To install Ollama (FREE, runs locally):

1. Go to: https://ollama.ai
2. Download for your OS
3. Install and run
4. Pull a model:

   ollama pull llama3.2      # 2GB, good balance
   ollama pull mistral       # 4GB, very capable
   ollama pull gemma2        # 5GB, best quality

Requirements:
- 8GB+ RAM recommended
- Works offline!
- No API costs ever!
""")

    return False

def check_google():
    """Check Google AI setup (FREE tier)"""
    print_header("GOOGLE AI SETUP (FREE - 60 req/min)")

    api_key = os.getenv("GOOGLE_API_KEY")

    if api_key:
        print("[OK] GOOGLE_API_KEY found")
        return True

    print("""
To get FREE Google AI access:

1. Go to: https://aistudio.google.com
2. Sign in with Google
3. Click "Get API Key"
4. Create key
5. Set environment variable:

   Windows:
   setx GOOGLE_API_KEY "your-key-here"

   Linux/Mac:
   export GOOGLE_API_KEY="your-key-here"

FREE Tier: 60 requests/minute
Model: Gemini 1.5 Flash (very capable)
""")

    return False

def install_dependencies():
    """Install required Python packages"""
    print_header("INSTALLING DEPENDENCIES")

    packages = [
        "langchain>=0.1.0",
        "langchain-groq",
        "langchain-ollama",
        "langchain-google-genai",
        "langchain-core",
    ]

    for package in packages:
        print(f"Installing {package}...")
        subprocess.run([
            sys.executable, "-m", "pip", "install", package, "-q"
        ])

    print("\n[OK] Dependencies installed!")

def main():
    print("""
    ╔════════════════════════════════════════════════╗
    ║     AfiCare FREE AI Setup                      ║
    ║     Choose your AI backend (all FREE!)         ║
    ╚════════════════════════════════════════════════╝
    """)

    # Check current status
    groq_ok = check_groq()
    ollama_ok = check_ollama()
    google_ok = check_google()

    print_header("SUMMARY")
    print(f"""
    Groq (Cloud):   {'[OK] Ready' if groq_ok else '[--] Not configured'}
    Ollama (Local): {'[OK] Ready' if ollama_ok else '[--] Not installed'}
    Google AI:      {'[OK] Ready' if google_ok else '[--] Not configured'}
    Rule-Based:     [OK] Always available (no setup needed)
    """)

    if not any([groq_ok, ollama_ok, google_ok]):
        print("""
RECOMMENDATION:
For quickest setup, use Groq (FREE cloud):
1. Get key from https://console.groq.com
2. Set GROQ_API_KEY environment variable
3. Done! You get 30 free requests/minute

For offline/unlimited use, install Ollama:
1. Download from https://ollama.ai
2. Run: ollama pull llama3.2
3. Done! Unlimited local AI
        """)

    # Ask to install dependencies
    response = input("\nInstall Python AI dependencies? (y/n): ")
    if response.lower() == 'y':
        install_dependencies()

    print("\nSetup complete! Run your AfiCare app to use AI features.")

if __name__ == "__main__":
    main()
