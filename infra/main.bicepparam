using 'main.bicep'

param appName = 'listmaster'
param environmentType = 'dev'
param pgAdminLogin = 'listmasteradmin'
param pgAdminPassword = readEnvironmentVariable('PG_ADMIN_PASSWORD', '')
param imageTag = readEnvironmentVariable('IMAGE_TAG', 'latest')
param whatsappVerifyToken = readEnvironmentVariable('WHATSAPP_VERIFY_TOKEN', '')
param whatsappApiToken = readEnvironmentVariable('WHATSAPP_API_TOKEN', '')
param openaiApiKey = readEnvironmentVariable('OPENAI_API_KEY', '')
