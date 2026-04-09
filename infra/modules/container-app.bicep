@description('Azure region for the Container App.')
param location string

@description('Name of the Container Apps Environment.')
param environmentName string

@description('Name of the Container App.')
param containerAppName string

@description('Log Analytics workspace customer ID.')
param logAnalyticsCustomerId string

@secure()
@description('Log Analytics workspace shared key.')
param logAnalyticsPrimaryKey string

@description('Container image to deploy (e.g. myregistry.azurecr.io/list-master:latest).')
param containerImage string

@description('ACR login server (e.g. myregistry.azurecr.io).')
param registryLoginServer string

@description('ACR admin username.')
param registryUsername string

@secure()
@description('ACR admin password.')
param registryPassword string

@description('DATABASE_URL for the application.')
@secure()
param databaseUrl string

@description('WhatsApp verify token.')
@secure()
param whatsappVerifyToken string = ''

@description('WhatsApp API token.')
@secure()
param whatsappApiToken string = ''

@description('OpenAI API key.')
@secure()
param openaiApiKey string = ''

@description('Tags to apply to resources.')
param tags object = {}

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
        sharedKey: logAnalyticsPrimaryKey
      }
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8000
        transport: 'auto'
        allowInsecure: false
      }
      registries: [
        {
          server: registryLoginServer
          username: registryUsername
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        { name: 'acr-password', value: registryPassword }
        { name: 'database-url', value: databaseUrl }
        { name: 'whatsapp-verify-token', value: whatsappVerifyToken }
        { name: 'whatsapp-api-token', value: whatsappApiToken }
        { name: 'openai-api-key', value: openaiApiKey }
      ]
    }
    template: {
      containers: [
        {
          name: 'list-master'
          image: containerImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            { name: 'DATABASE_URL', secretRef: 'database-url' }
            { name: 'DEBUG', value: 'false' }
            { name: 'WHATSAPP_VERIFY_TOKEN', secretRef: 'whatsapp-verify-token' }
            { name: 'WHATSAPP_API_TOKEN', secretRef: 'whatsapp-api-token' }
            { name: 'OPENAI_API_KEY', secretRef: 'openai-api-key' }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8000
              }
              initialDelaySeconds: 10
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 8000
              }
              initialDelaySeconds: 5
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 3
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '50'
              }
            }
          }
        ]
      }
    }
  }
}

output fqdn string = containerApp.properties.configuration.ingress.fqdn
output environmentId string = environment.id
