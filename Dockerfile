# =========================
#  Stage 1 — builder
#  - Compila wheels (inclusive psycopg2) em Alpine
# =========================
FROM python:3.12-alpine AS builder

# Dependências de build para compilar psycopg2
RUN apk add --no-cache build-base postgresql-dev

# Ambiente do builder
WORKDIR /app

# Copia e prepara dependências
# (mantém cache de camadas quando só o código muda)
COPY app/requirements.txt ./requirements.txt

# Cria venv e constrói wheels de todas as deps
RUN python -m venv /opt/venv && \
    . /opt/venv/bin/activate && \
    pip install --upgrade pip wheel && \
    pip wheel --no-cache-dir --no-deps -r requirements.txt -w /wheels

# =========================
#  Stage 2 — runtime
#  - Imagem mínima, somente libs de runtime
# =========================
FROM python:3.12-alpine AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# Somente runtime do Postgres (libpq) — necessário para psycopg2
RUN apk add --no-cache libpq

# Cria usuário não-root por segurança
RUN addgroup -S app && adduser -S -G app app

# Diretório da aplicação
WORKDIR /app

# Cria venv e instala as wheels construídas no stage builder
COPY --from=builder /wheels /wheels
RUN python -m venv /opt/venv && \
    . /opt/venv/bin/activate && \
    pip install --no-cache-dir /wheels/* && \
    rm -rf /wheels

# Copia o código da aplicação
COPY app/ /app/

# Ajusta permissões e troca o usuário
RUN chown -R app:app /app
USER app

# Porta padrão da API
EXPOSE 8000

# Comando — gunicorn servindo o objeto WSGI "wsgi:app"
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8000", "wsgi:app"]
