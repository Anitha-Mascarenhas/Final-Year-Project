FROM python:3.11-slim

# Prevent Python from buffering stdout/stderr (useful for container logs)
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# No extra system dependencies needed:
# TFLite runtime is self-contained, Pillow wheels include native libs.

# Copy backend requirements and install Python dependencies
COPY backend/requirements.txt /app/backend/requirements.txt
RUN pip install --no-cache-dir -r /app/backend/requirements.txt

# Copy backend source code and required model artifacts
COPY backend/app.py /app/backend/app.py
COPY backend/predict.py /app/backend/predict.py
COPY backend/models/best_model.tflite /app/backend/models/best_model.tflite
COPY backend/models/label_encoder.pkl /app/backend/models/label_encoder.pkl

# Create the uploads directory (writable at runtime)
RUN mkdir -p /app/backend/uploads

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"]

CMD ["uvicorn", "backend.app:app", "--host", "0.0.0.0", "--port", "8000"]
