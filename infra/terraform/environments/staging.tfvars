environment = "staging"
location    = "westus2"

# Database — small tier for staging
db_sku        = "B_Standard_B1ms"
db_storage_mb = 32768

# Container App — minimal resources for staging
acr_sku          = "Basic"
min_replicas     = 1
max_replicas     = 3
container_cpu    = 0.5
container_memory = "1Gi"
