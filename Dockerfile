FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY src/ ./src/
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3   CMD curl -f http://localhost:8000/api/health || exit 1
CMD ["uvicorn", "maps.api.app:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000"]
