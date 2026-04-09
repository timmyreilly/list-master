variable "environment" {
  description = "Deployment environment (staging or prod)"
  type        = string
  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "Environment must be 'staging' or 'prod'."
  }
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westus2"
}

variable "image_tag" {
  description = "Container image tag (git SHA)"
  type        = string
  default     = "latest"
}

# ── Database ────────────────────────────────────────────────────────────

variable "db_admin_user" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "listmasteradmin"
}

variable "db_admin_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

variable "db_sku" {
  description = "PostgreSQL Flexible Server SKU"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "db_storage_mb" {
  description = "PostgreSQL storage in MB"
  type        = number
  default     = 32768
}

# ── Container App ───────────────────────────────────────────────────────

variable "acr_sku" {
  description = "Azure Container Registry SKU"
  type        = string
  default     = "Basic"
}

variable "min_replicas" {
  description = "Minimum container replicas"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum container replicas"
  type        = number
  default     = 3
}

variable "container_cpu" {
  description = "Container CPU allocation"
  type        = number
  default     = 0.5
}

variable "container_memory" {
  description = "Container memory allocation"
  type        = string
  default     = "1Gi"
}
