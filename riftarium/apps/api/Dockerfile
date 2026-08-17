FROM python:3.14-slim

WORKDIR /srv

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ app/
COPY tests/ tests/
COPY pytest.ini .

EXPOSE 8000

HEALTHCHECK --interval=15s --timeout=3s --start-period=30s --retries=5 \
  CMD python -c "import httpx; httpx.get('http://127.0.0.1:8000/api/health').raise_for_status()"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
