perfeito — vamos criar a documentação.

## `README.md` (raiz do repositório)

```markdown
# DevOps Multi-Container (Alpine) — Flask + PostgreSQL

Ambiente **multi-container** com **API CRUD** (Flask) e **PostgreSQL**, usando:
- **Dockerfile** multi-stage baseado em **Alpine**
- **Docker Compose** com **rede dedicada** e **volume persistente**
- **Variáveis de ambiente** via `.env`
- **Usuário de aplicação** no banco (evitando uso do superusuário)

---

## 📦 Arquitetura

```

host
└─ docker
├─ network: app_net
│   ├─ devops_app  (Python/Flask, Gunicorn, Alpine)  → porta 8000 no host
│   └─ devops_db   (PostgreSQL 16 Alpine)            → somente rede interna
└─ volume: db_data → /var/lib/postgresql/data (persistência do banco)

````

## 🧰 Stack

- **API**: Python 3.12 + Flask + SQLAlchemy + Gunicorn  
- **DB**: PostgreSQL 16 (imagem `-alpine`)  
- **Base**: Linux **Alpine** em todos os serviços  
- **Orquestração**: Docker Compose  

---

## ✅ Requisitos

- Docker 24+ e **Docker Compose** (plugin)  
- Git  
- (Opcional) `curl` e `jq` para testar endpoints

---

## 🔐 Variáveis de ambiente

Crie um `.env` a partir de `.env.example`:

| Variável            | Serviço | Padrão (dev)                | Observação |
|---------------------|---------|-----------------------------|------------|
| `APP_PORT`          | app     | `8000`                      | Porta exposta no host |
| `SECRET_KEY`        | app     | `change-me`                 | Troque em produção |
| `DATABASE_URL`      | app     | *(vazio)*                   | Se definido, ignora `APP_DB_*` e `DB_*` |
| `APP_DB_USER`       | app/db  | `app_user`                  | Usuário **não-root** da aplicação |
| `APP_DB_PASSWORD`   | app/db  | `app_password`              | Senha do usuário da aplicação |
| `APP_DB_NAME`       | app/db  | `app_db`                    | Banco da aplicação |
| `DB_HOST`           | app     | `db`                        | Nome do serviço Postgres no Compose |
| `DB_PORT`           | app     | `5432`                      | Porta interna |
| `DB_SUPERUSER`      | db      | `postgres_admin`            | Superusuário **apenas** para bootstrap |
| `DB_SUPERPASS`      | db      | `postgres_admin_password`   | Senha do superusuário |
| `DB_SUPERDB`        | db      | `postgres`                  | DB de administração |

> **Segurança**: a aplicação **não usa** o superusuário. O script `db/init/00-create-app-user.sh` cria o usuário da aplicação com permissões mínimas.

---

## 🚀 Subir o ambiente

```bash
# 1) copiar variáveis
cp .env.example .env
# (edite segredos para produção)

# 2) build das imagens
docker compose build

# 3) subir serviços
docker compose up -d

# 4) verificar status
docker compose ps
docker compose logs -f app
````

A API ficará em: **[http://localhost:8000](http://localhost:8000)**

---

## 🧪 Endpoints

### Healthcheck

```
GET /health
```

**Exemplo:**

```bash
curl -s http://localhost:8000/health
```

### CRUD — Items

* `GET /items` — lista (query opcional `?search=...`)
* `POST /items` — cria (`{"name": "...", "description": "..."}`)
* `GET /items/<id>` — obtém por id
* `PUT /items/<id>` — atualiza (`{"name": "...", "description": "..."}`)
* `DELETE /items/<id>` — remove por id

**Exemplos:**

```bash
# Criar
curl -s -X POST http://localhost:8000/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Primeiro item","description":"exemplo"}'

# Listar
curl -s http://localhost:8000/items

# Buscar
curl -s "http://localhost:8000/items?search=Primeiro"

# Atualizar (id=1)
curl -s -X PUT http://localhost:8000/items/1 \
  -H "Content-Type: application/json" \
  -d '{"description":"atualizado"}'

# Deletar (id=1)
curl -s -X DELETE http://localhost:8000/items/1
```

---

## 🗄️ Banco de dados e permissões

O container `db` executa, no primeiro start, `db/init/00-create-app-user.sh` que:

1. Cria o **ROLE** `${APP_DB_USER}` com **LOGIN** (sem super poderes).
2. Cria o DB `${APP_DB_NAME}` com **owner = ${APP_DB_USER}`** (se não existir).
3. **Revoga** permissões amplas de `PUBLIC` e concede apenas o necessário à app.
4. Ajusta **default privileges** para tabelas/seq futuras.

Conferir via `psql`:

```bash
docker compose exec -it db psql -U "$DB_SUPERUSER" -d "$DB_SUPERDB" -c "\du"
docker compose exec -it db psql -U "$DB_SUPERUSER" -d "$APP_DB_NAME"  -c "\dn+"
docker compose exec -it db psql -U "$DB_SUPERUSER" -d "$APP_DB_NAME"  -c "\dt"
```

> Porta do Postgres **não é exposta** no host; acesso é feito pela rede interna `app_net`.

---

## 💾 Volumes e backup

* Dados do DB persistem no volume `db_data`.

Backup (dump lógico):

```bash
docker compose exec -T db pg_dump -U "$APP_DB_USER" -d "$APP_DB_NAME" > backup.sql
```

Restore:

```bash
docker compose exec -T db psql -U "$APP_DB_USER" -d "$APP_DB_NAME" < backup.sql
```

---

## 🔄 Ciclo de vida

```bash
# Subir
docker compose up -d

# Logs (app)
docker compose logs -f app

# Parar
docker compose down

# Parar e remover volume (⚠️ perde dados)
docker compose down -v
```

---

## 🛡️ Boas práticas aplicadas

* **Alpine** em todos os serviços → imagens enxutas
* **Multi-stage build** → runtime mínimo (somente dependências necessárias)
* **Usuário não-root** no container da aplicação
* **Sem expor** a porta do Postgres para o host
* **Variáveis de ambiente** via `.env` (sem segredos no código)
* **Healthcheck** no DB e `depends_on` no app

---

## 🧩 Estrutura do repositório

```
.
├─ app/
│  ├─ __init__.py
│  ├─ main.py
│  ├─ requirements.txt
│  └─ wsgi.py
├─ db/
│  └─ init/
│     └─ 00-create-app-user.sh
├─ .env.example
├─ .gitignore
├─ Dockerfile
├─ docker-compose.yml
└─ README.md
```

---

## ❗ Troubleshooting

* **`ModuleNotFoundError`/`ImportError`**
  Garanta que o build foi refeito quando mudar `requirements.txt`:
  `docker compose build --no-cache app && docker compose up -d`

* **`psycopg2` build no Alpine**
  O `Dockerfile` usa `builder` com `build-base` + `postgresql-dev` para compilar wheels; o `runtime` instala apenas `libpq`.

* **Script de init não executou**
  O Postgres só roda scripts da pasta `/docker-entrypoint-initdb.d` **no primeiro início** (quando o diretório de dados está vazio).
  Se já inicializou sem o script, remova o volume `db_data` (⚠️ perde dados) e suba novamente:

  ```bash
  docker compose down -v
  docker compose up -d
  ```

---

## 📜 Licença

Uso acadêmico/educacional.
