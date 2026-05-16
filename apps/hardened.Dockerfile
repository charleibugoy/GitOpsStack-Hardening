# 1. Minimal base image
FROM python:3.11-slim

# 2. Patch OS packages and clean up (reduces CVEs)
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 3. Create non-root user
RUN groupadd -r appgroup && useradd -r -g appgroup appuser

# 4. Install Python dependencies (no cache)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 5. Copy application code with correct ownership
COPY --chown=appuser:appgroup . .

# 6. Switch to non-root user
USER appuser

# 7. SecurityContext equivalent in image
EXPOSE 8080

# 8. Health check (required for many DoD workloads)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

CMD ["python", "app.py"]
