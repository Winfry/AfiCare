# 🏥 AfiCare Crash Fix Guide

## Problem Identified

Your app was crashing due to:
1. **Port conflict** - Port 8501 already in use or blocked by firewall
2. **Missing LLM graceful fallback** - App tried to use LLM even when not loaded
3. **JSON file loading errors** - Some knowledge base files had issues

## ✅ Fixes Applied

### 1. Agent Core (`src/core/agent.py`)
- Added graceful fallback when LLM is not available
- Fixed `get_system_status()` to handle missing methods safely
- App now works WITHOUT LLM (uses rule engine only)

### 2. New Helper Scripts Created

#### `diagnose_issues.py` - Full System Diagnostic
```bash
python diagnose_issues.py
```
Checks:
- Python version
- Dependencies
- JSON knowledge base files
- Config files
- Database files
- Source code structure
- Port availability

#### `start_dev_app.py` - Simple Starter
```bash
python start_dev_app.py
```
- Automatically finds available port
- Kills existing Streamlit processes
- Starts app on port 8505 (avoids conflicts)

#### `fix_and_run.py` - Advanced Fix & Start
```bash
python fix_and_run.py
```
- Runs full diagnostics
- Fixes common issues
- Finds available port
- Starts the app

## 🚀 Quick Start (3 Steps)

### Step 1: Run Diagnostics
```bash
cd aficare-agent
python diagnose_issues.py
```

### Step 2: Fix Any Issues
If diagnostics show problems, they'll be listed with solutions.

### Step 3: Start the App
```bash
python start_dev_app.py
```

## 📱 Access URLs

After starting:
- **Local**: http://localhost:8505
- **Mobile**: http://192.168.100.5:8505

## 🔧 Common Issues & Solutions

### Issue: Port Already in Use
**Error**: `PermissionError: [WinError 10013]`

**Solution**:
```bash
# Kill existing Streamlit processes
taskkill /F /FI "WINDOWTITLE eq streamlit*"

# Or use the start script (does this automatically)
python start_dev_app.py
```

### Issue: JSON Loading Errors
**Error**: `Expecting value: line 1 column 1 (char 0)`

**Solution**:
```bash
# Run diagnostics to identify bad JSON files
python diagnose_issues.py

# Check the specific files mentioned
# They might be empty or corrupted
```

### Issue: LLM Not Available
**Warning**: `llama-cpp-python not installed`

**This is OK!** The app now works without LLM:
- Uses rule-based engine for diagnoses
- All features work except advanced AI reasoning
- To enable LLM (optional):
  ```bash
  pip install llama-cpp-python
  ```

### Issue: Import Errors
**Error**: `ModuleNotFoundError`

**Solution**:
```bash
# Install requirements
pip install -r requirements.txt

# Or install individually
pip install streamlit asyncio pathlib
```

## 🎯 What Works Now

✅ App starts without crashing
✅ Works without LLM (rule engine only)
✅ Automatic port selection
✅ Graceful error handling
✅ Patient consultations
✅ Triage assessment
✅ Condition matching
✅ Treatment recommendations

## 📊 System Status

The app will show:
- **LLM Status**: ❌ Not Loaded (this is fine!)
- **Medical Rules**: ✅ X conditions loaded
- **Database**: ✅ Connected
- **Plugins**: ✅ Loaded

## 🔄 Next Steps

1. **Test the app**: Run `python start_dev_app.py`
2. **Try a consultation**: Use demo accounts
3. **Check mobile access**: Use network URL on phone
4. **Deploy globally**: Use `deploy_global_simple.py` when ready

## 💡 Pro Tips

- Use `start_dev_app.py` for quick testing
- Use `diagnose_issues.py` when troubleshooting
- Use `fix_and_run.py` for comprehensive fix + start
- Check logs in `logs/` directory for detailed errors

## 🆘 Still Having Issues?

Run full diagnostic:
```bash
python diagnose_issues.py
```

This will show exactly what's wrong and how to fix it.

---

**Last Updated**: 2026-03-04
**Status**: ✅ Crash issues fixed, app ready to run
