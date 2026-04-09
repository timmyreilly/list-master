@description('Azure region for the PostgreSQL Flexible Server.')
param location string

@description('Name of the PostgreSQL Flexible Server.')
param serverName string

@description('Administrator login name.')
param administratorLogin string

@secure()
@description('Administrator login password.')
param administratorPassword string

@description('PostgreSQL version.')
@allowed(['14', '15', '16'])
param postgresVersion string = '16'

@description('SKU tier for the Flexible Server.')
@allowed(['Burstable', 'GeneralPurpose', 'MemoryOptimized'])
param skuTier string = 'Burstable'

@description('SKU name (e.g. Standard_B1ms for Burstable).')
param skuName string = 'Standard_B1ms'

@description('Storage size in GB.')
param storageSizeGB int = 32

@description('Name of the application database to create.')
param databaseName string = 'listmaster'

@description('Tags to apply to resources.')
param tags object = {}

resource server 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    version: postgresVersion
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    storage: {
      storageSizeGB: storageSizeGB
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }
}

// Allow Azure services (Container Apps) to connect
resource firewallRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = {
  parent: server
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  parent: server
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

output serverFqdn string = server.properties.fullyQualifiedDomainName
output serverName string = server.name
output databaseName string = database.name
