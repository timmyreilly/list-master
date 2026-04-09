# List Master

Shared grocery list app — multiple users send messages to a WhatsApp number,
an LLM parses them, and a web UI shows the up-to-date list.

## Tech Stack

- **Backend:** FastAPI + Uvicorn
- **UI:** HTMX / Jinja2 server-rendered templates
- **Database:** PostgreSQL (asyncpg + SQLAlchemy async)
- **Hosting:** Azure Container Apps

## Local Development

### Prerequisites

- Docker & Docker Compose

### Quick Start

```bash
cp .env.example .env          # configure secrets
docker compose up --build     # start app + Postgres
```

The API is available at **http://localhost:8000**.  
Health check: `GET /health` → `{"status": "ok"}`

### Useful Commands

```bash
docker compose up -d           # start in background
docker compose logs -f app     # tail app logs
docker compose down -v         # stop and remove volumes
```

### Without Docker

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
# ensure Postgres is running and DATABASE_URL is set in .env
uvicorn app.main:app --reload --port 8000
```