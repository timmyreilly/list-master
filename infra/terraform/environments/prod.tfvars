environment = "prod"
location    = "westus2"

# Database — production tier
db_sku        = "GP_Standard_D2ds_v5"
db_storage_mb = 65536

# Container App — production resources
acr_sku          = "Standard"
min_replicas     = 2
max_replicas     = 10
container_cpu    = 1.0
container_memory = "2Gi"
