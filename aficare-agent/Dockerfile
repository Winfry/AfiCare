# AfiCare MediLink - Production Docker Image
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy and install requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && rm -rf /root/.cache

# Copy application code
COPY src/ src/
COPY config/ config/
COPY data/knowledge_base/ data/knowledge_base/
COPY plugins/ plugins/
COPY static/ static/
COPY pyproject.toml .

# Create necessary directories
RUN mkdir -p logs data/models

# Set environment variables
ENV PYTHONPATH=/app
ENV PORT=8080

EXPOSE ${PORT}

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

CMD uvicorn src.api.main:app --host 0.0.0.0 --port ${PORT}
