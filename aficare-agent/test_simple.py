"""
Simple test to verify Streamlit is working
"""

import streamlit as st

st.title("🏥 AfiCare MediLink - Test Page")
st.write("If you can see this, Streamlit is working!")

st.success("✅ Basic Streamlit functionality is working")

# Test database creation
import sqlite3
from pathlib import Path

try:
    db_path = "test.db"
    with sqlite3.connect(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute("CREATE TABLE IF NOT EXISTS test (id INTEGER PRIMARY KEY, name TEXT)")
        cursor.execute("INSERT INTO test (name) VALUES (?)", ("Test Entry",))
        conn.commit()
        
        cursor.execute("SELECT * FROM test")
        results = cursor.fetchall()
        
    st.success(f"✅ Database test successful! Found {len(results)} entries")
    
    # Clean up
    Path(db_path).unlink(missing_ok=True)
    
except Exception as e:
    st.error(f"❌ Database test failed: {str(e)}")

st.info("💡 If both tests pass, the basic functionality is working and we can proceed with the full database version.")