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

## Azure Deployment

The app deploys to **Azure Container Apps** with Bicep templates in `infra/`.

### Resources Provisioned

| Resource | Purpose |
|----------|---------|
| Log Analytics Workspace | Container Apps logging |
| Azure Container Registry | Docker image storage |
| PostgreSQL Flexible Server | Application database |
| Container Apps Environment | Serverless container hosting |
| Container App | The List Master service |

### Prerequisites

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- An Azure subscription

### Deploy

```bash
# Login and set subscription
az login
az account set --subscription <subscription-id>

# Create a resource group
az group create --name rg-listmaster-dev --location eastus

# Deploy infrastructure
az deployment group create \
  --resource-group rg-listmaster-dev \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam

# Build and push the container image
az acr login --name <acr-name>
docker build -t <acr-login-server>/listmaster:latest .
docker push <acr-login-server>/listmaster:latest
```

### Environment Configuration

Secrets are passed via `main.bicepparam` which reads from environment variables:

| Env Var | Description |
|---------|-------------|
| `PG_ADMIN_PASSWORD` | PostgreSQL admin password (required) |
| `IMAGE_TAG` | Container image tag (default: `latest`) |
| `WHATSAPP_VERIFY_TOKEN` | WhatsApp webhook verification token |
| `WHATSAPP_API_TOKEN` | WhatsApp Cloud API token |
| `OPENAI_API_KEY` | OpenAI API key for LLM parsing |

### Environments

Use `environmentType` parameter to switch between `dev`, `staging`, and `prod`.
Each environment automatically adjusts:
- **dev**: Burstable Postgres (B1ms), Basic ACR, scale-to-zero
- **staging**: Same as dev (override SKUs as needed)
- **prod**: GeneralPurpose Postgres (D2ds_v4), Standard ACR