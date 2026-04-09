// ---------------------------------------------------------------------------
// List Master — Azure Container Apps deployment
//
// Deploys: Log Analytics, Container Registry, PostgreSQL Flexible Server,
//          Container Apps Environment + App
// ---------------------------------------------------------------------------

targetScope = 'resourceGroup'

// ── Parameters ──────────────────────────────────────────────────────────────

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Base name used to derive resource names (lowercase, no hyphens > 24 chars for ACR).')
@minLength(3)
@maxLength(20)
param appName string = 'listmaster'

@description('Short environment label (dev / staging / prod).')
@allowed(['dev', 'staging', 'prod'])
param environmentType string = 'dev'

@description('PostgreSQL administrator login.')
param pgAdminLogin string = 'listmasteradmin'

@secure()
@description('PostgreSQL administrator password.')
param pgAdminPassword string

@description('Container image tag to deploy.')
param imageTag string = 'latest'

@description('WhatsApp verify token.')
@secure()
param whatsappVerifyToken string = ''

@description('WhatsApp API token.')
@secure()
param whatsappApiToken string = ''

@description('OpenAI API key.')
@secure()
param openaiApiKey string = ''

// ── Derived names ───────────────────────────────────────────────────────────

var suffix = '${appName}-${environmentType}'
var acrName = replace('${appName}${environmentType}acr', '-', '')  // ACR requires alphanumeric
var tags = {
  app: appName
  environment: environmentType
}

// ── Modules ─────────────────────────────────────────────────────────────────

module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'log-analytics'
  params: {
    location: location
    workspaceName: 'law-${suffix}'
    tags: tags
  }
}

module acr 'modules/container-registry.bicep' = {
  name: 'container-registry'
  params: {
    location: location
    registryName: acrName
    sku: environmentType == 'prod' ? 'Standard' : 'Basic'
    tags: tags
  }
}

module postgres 'modules/postgres.bicep' = {
  name: 'postgres'
  params: {
    location: location
    serverName: 'psql-${suffix}'
    administratorLogin: pgAdminLogin
    administratorPassword: pgAdminPassword
    postgresVersion: '16'
    skuTier: environmentType == 'prod' ? 'GeneralPurpose' : 'Burstable'
    skuName: environmentType == 'prod' ? 'Standard_D2ds_v4' : 'Standard_B1ms'
    storageSizeGB: environmentType == 'prod' ? 64 : 32
    databaseName: 'listmaster'
    tags: tags
  }
}

// Build DATABASE_URL from Postgres outputs
var databaseUrl = 'postgresql+asyncpg://${pgAdminLogin}:${pgAdminPassword}@${postgres.outputs.serverFqdn}:5432/${postgres.outputs.databaseName}?ssl=require'

// Retrieve ACR credentials via listCredentials
resource acrRef 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acr.outputs.registryName
}

module containerApp 'modules/container-app.bicep' = {
  name: 'container-app'
  params: {
    location: location
    environmentName: 'cae-${suffix}'
    containerAppName: 'ca-${suffix}'
    logAnalyticsCustomerId: logAnalytics.outputs.customerId
    logAnalyticsPrimaryKey: logAnalytics.outputs.primarySharedKey
    containerImage: '${acr.outputs.loginServer}/${appName}:${imageTag}'
    registryLoginServer: acr.outputs.loginServer
    registryUsername: acrRef.listCredentials().username
    registryPassword: acrRef.listCredentials().passwords[0].value
    databaseUrl: databaseUrl
    whatsappVerifyToken: whatsappVerifyToken
    whatsappApiToken: whatsappApiToken
    openaiApiKey: openaiApiKey
    tags: tags
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────

output appUrl string = 'https://${containerApp.outputs.fqdn}'
output acrLoginServer string = acr.outputs.loginServer
output postgresServerFqdn string = postgres.outputs.serverFqdn
