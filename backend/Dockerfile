FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Install system dependencies (curl needed for healthcheck)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies first (layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source
COPY . .

# Set Python path to include the app directory
ENV PYTHONPATH=/app

# Expose the API port (Cloud Run expects 8080, but we'll use PORT env var)
EXPOSE 8080

# Health check for Cloud Run (use PORT env var or default to 8080)
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:${PORT:-8080}/health || exit 1

# Run uvicorn on container start
# Use PORT environment variable (Cloud Run requirement) or default to 8080
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080} --workers 1"]
