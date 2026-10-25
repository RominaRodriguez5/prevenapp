FROM python:3.12-slim
WORKDIR /code
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
# 1) Aplica las migraciones (crea/actualiza las tablas)  2) arranca la API
# En la nube (Render) el puerto lo indica la variable PORT; en el ordenador, 8000.
# (En desarrollo, docker-compose.yml lo arranca con --reload para ver los cambios al guardar.)
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
