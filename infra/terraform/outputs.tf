output "resource_group" {
  description = "Resource group name"
  value       = azurerm_resource_group.main.name
}

output "acr_login_server" {
  description = "Azure Container Registry login server"
  value       = azurerm_container_registry.main.login_server
}

output "container_app_name" {
  description = "Container App name"
  value       = azurerm_container_app.api.name
}

output "container_app_url" {
  description = "Container App FQDN"
  value       = "https://${azurerm_container_app.api.ingress[0].fqdn}"
}

output "db_host" {
  description = "PostgreSQL server FQDN"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "db_name" {
  description = "PostgreSQL database name"
  value       = azurerm_postgresql_flexible_server_database.app.name
}
