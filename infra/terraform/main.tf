terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Backend configured via -backend-config in CI; local runs use -backend-config=false override
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  # use_oidc = true  # Enable in CI; local runs use az cli auth
}

# ── Resource Group ──────────────────────────────────────────────────────

resource "azurerm_resource_group" "main" {
  name     = "rg-listmaster-${var.environment}"
  location = var.location

  tags = local.tags
}

# ── Container Registry ──────────────────────────────────────────────────

resource "azurerm_container_registry" "main" {
  name                = "crlistmaster${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.acr_sku
  admin_enabled       = false

  tags = local.tags
}

# ── Log Analytics ───────────────────────────────────────────────────────

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-listmaster-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.tags
}

# ── Container Apps Environment ──────────────────────────────────────────

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-listmaster-${var.environment}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  tags = local.tags
}

# ── PostgreSQL Flexible Server ──────────────────────────────────────────

resource "azurerm_postgresql_flexible_server" "main" {
  name                          = "psql-listmaster-${var.environment}"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  version                       = "16"
  administrator_login           = var.db_admin_user
  administrator_password        = var.db_admin_password
  sku_name                      = var.db_sku
  storage_mb                    = var.db_storage_mb
  backup_retention_days         = var.environment == "prod" ? 30 : 7
  geo_redundant_backup_enabled  = var.environment == "prod"
  public_network_access_enabled = true

  tags = local.tags
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "listmaster"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Allow Azure services to connect to Postgres
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# ── Container App ───────────────────────────────────────────────────────

resource "azurerm_container_app" "api" {
  name                         = "ca-listmaster-${var.environment}"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "api"
      image  = "${azurerm_container_registry.main.login_server}/list-master:${var.image_tag}"
      cpu    = var.container_cpu
      memory = var.container_memory

      env {
        name  = "DATABASE_URL"
        value = local.database_url
      }
      env {
        name  = "DEBUG"
        value = var.environment == "prod" ? "false" : "true"
      }

      liveness_probe {
        transport = "HTTP"
        path      = "/health"
        port      = 8000

        initial_delay    = 10
        interval_seconds = 30
        timeout          = 5
        failure_count_threshold = 3
      }

      readiness_probe {
        transport = "HTTP"
        path      = "/health"
        port      = 8000

        interval_seconds = 10
        timeout          = 3
        failure_count_threshold = 3
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.acr_pull.id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.acr_pull.id]
  }

  tags = local.tags
}

# ── Managed Identity for ACR Pull ───────────────────────────────────────

resource "azurerm_user_assigned_identity" "acr_pull" {
  name                = "id-listmaster-acrpull-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = local.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.acr_pull.principal_id
}

# ── Locals ──────────────────────────────────────────────────────────────

locals {
  database_url = "postgresql+asyncpg://${var.db_admin_user}:${var.db_admin_password}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/listmaster?ssl=require"

  tags = {
    project     = "list-master"
    environment = var.environment
    managed_by  = "terraform"
  }
}
