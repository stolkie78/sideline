using './main.bicep'

param environment = 'prod'
param pbAdminEmail = readEnvironmentVariable('PB_ADMIN_EMAIL', '')
param pbAdminPassword = readEnvironmentVariable('PB_ADMIN_PASSWORD', '')
param googleClientId = readEnvironmentVariable('GOOGLE_CLIENT_ID', '')
param googleClientSecret = readEnvironmentVariable('GOOGLE_CLIENT_SECRET', '')
