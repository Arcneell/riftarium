FROM python:3.12-slim

WORKDIR /srv

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && useradd --create-home --uid 1000 --shell /usr/sbin/nologin app

COPY --chown=app:app app/ app/
COPY --chown=app:app tests/ tests/
COPY --chown=app:app pytest.ini .

USER app
EXPOSE 8000

HEALTHCHECK --interval=15s --timeout=3s --start-period=30s --retries=5 \
  CMD python -c "import httpx; httpx.get('http://127.0.0.1:8000/api/health').raise_for_status()"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
