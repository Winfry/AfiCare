# AfiCare MediLink - Production Docker Image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (for better Docker layer caching)
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p logs data scripts

# Set environment variables
ENV PYTHONPATH=/app
ENV STREAMLIT_SERVER_PORT=8501
ENV STREAMLIT_SERVER_ADDRESS=0.0.0.0
ENV STREAMLIT_SERVER_HEADLESS=true
ENV STREAMLIT_BROWSER_GATHER_USAGE_STATS=false

# Expose port
EXPOSE 8501

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8501/_stcore/health || exit 1

# Initialize database and start app
CMD ["python", "-c", "\
import os; \
import subprocess; \
import sys; \
print('🏥 AfiCare MediLink - Starting Production Server'); \
print('='*50); \
if not os.getenv('DATABASE_URL'): \
    print('📊 Creating sample data for local/demo deployment...'); \
    subprocess.run([sys.executable, 'scripts/populate_sample_data.py']); \
print('🚀 Starting Streamlit application...'); \
subprocess.run([ \
    'streamlit', 'run', 'medilink_simple.py', \
    '--server.port', os.getenv('PORT', '8501'), \
    '--server.address', '0.0.0.0', \
    '--server.headless', 'true' \
])"]