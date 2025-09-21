ARG PYTHON_VERSION=3.10
FROM python:${PYTHON_VERSION}-slim

# Set work directory
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app ./app

# Expose port (use 8080 for consistency across languages)
ENV PORT=8080
EXPOSE 8080

# Start Uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]