FROM python:3.14-slim

WORKDIR /srv

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && useradd --create-home --uid 1000 --shell /usr/sbin/nologin app

# Image de prod minimale : ni tests/ ni pytest.ini (les tests tournent en CI
# et en local, hors Docker — voir riftarium/README.md).
COPY --chown=app:app app/ app/
# Migrations Alembic : appliquées automatiquement au démarrage (app/db.py, run_migrations).
COPY --chown=app:app alembic.ini .
COPY --chown=app:app alembic/ alembic/

USER app
EXPOSE 8000

HEALTHCHECK --interval=15s --timeout=3s --start-period=30s --retries=5 \
  CMD python -c "import httpx; httpx.get('http://127.0.0.1:8000/api/health').raise_for_status()"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
