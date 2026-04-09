@description('Azure region for the Log Analytics workspace.')
param location string

@description('Name of the Log Analytics workspace.')
param workspaceName string

@description('Tags to apply to resources.')
param tags object = {}

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

output workspaceId string = workspace.id
output customerId string = workspace.properties.customerId
output primarySharedKey string = workspace.listKeys().primarySharedKey
