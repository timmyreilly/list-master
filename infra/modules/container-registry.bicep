@description('Azure region for the Container Registry.')
param location string

@description('Name of the Azure Container Registry.')
param registryName string

@description('SKU for the Container Registry.')
@allowed(['Basic', 'Standard', 'Premium'])
param sku string = 'Basic'

@description('Tags to apply to resources.')
param tags object = {}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: registryName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: true
  }
}

output registryId string = acr.id
output loginServer string = acr.properties.loginServer
output registryName string = acr.name
