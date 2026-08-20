// SetBaas - Azure Container Apps Infrastructure
// Deploy: az deployment group create -g setbaas-rg -f infra/main.bicep -p infra/main.bicepparam

@description('Environment name (dev, staging, prod)')
param environment string = 'prod'

@description('Azure region')
param location string = resourceGroup().location

@description('PocketBase admin email')
@secure()
param pbAdminEmail string

@description('PocketBase admin password')
@secure()
param pbAdminPassword string

@description('Google OAuth Client ID')
@secure()
param googleClientId string

@description('Google OAuth Client Secret')
@secure()
param googleClientSecret string

var prefix = 'setbaas-${environment}'
var acrName = replace('setbaas${environment}acr', '-', '')

// Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

// Log Analytics Workspace (required for Container Apps Environment)
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${prefix}-logs'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Storage Account for PocketBase data
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: replace('${prefix}storage', '-', '')
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource pbDataShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: fileService
  name: 'pb-data'
  properties: {
    shareQuota: 1
  }
}

// Container Apps Environment
resource containerEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: '${prefix}-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// Mount Azure File Share in environment
resource storageMount 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  parent: containerEnv
  name: 'pbdata'
  properties: {
    azureFile: {
      accountName: storageAccount.name
      accountKey: storageAccount.listKeys().keys[0].value
      shareName: pbDataShare.name
      accessMode: 'ReadWrite'
    }
  }
}

// PocketBase Container App
resource pocketbase 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${prefix}-pocketbase'
  location: location
  properties: {
    managedEnvironmentId: containerEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8090
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: acr.properties.loginServer
          username: acr.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: acr.listCredentials().passwords[0].value
        }
        {
          name: 'pb-admin-email'
          value: pbAdminEmail
        }
        {
          name: 'pb-admin-password'
          value: pbAdminPassword
        }
        {
          name: 'google-client-id'
          value: googleClientId
        }
        {
          name: 'google-client-secret'
          value: googleClientSecret
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'pocketbase'
          image: '${acr.properties.loginServer}/setbaas-pocketbase:latest'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            { name: 'PB_ADMIN_EMAIL', secretRef: 'pb-admin-email' }
            { name: 'PB_ADMIN_PASSWORD', secretRef: 'pb-admin-password' }
            { name: 'GOOGLE_CLIENT_ID', secretRef: 'google-client-id' }
            { name: 'GOOGLE_CLIENT_SECRET', secretRef: 'google-client-secret' }
          ]
          volumeMounts: [
            {
              volumeName: 'pbdata'
              mountPath: '/pb/pb_data'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      volumes: [
        {
          name: 'pbdata'
          storageName: storageMount.name
          storageType: 'AzureFile'
        }
      ]
    }
  }
}

// Frontend Container App
resource frontend 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${prefix}-frontend'
  location: location
  properties: {
    managedEnvironmentId: containerEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 3000
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: acr.properties.loginServer
          username: acr.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: acr.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'frontend'
          image: '${acr.properties.loginServer}/setbaas-frontend:latest'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'PUBLIC_POCKETBASE_URL'
              value: 'https://${prefix}-pocketbase.${containerEnv.properties.defaultDomain}'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 2
      }
    }
  }
}

// Outputs
output acrLoginServer string = acr.properties.loginServer
output pocketbaseUrl string = 'https://${pocketbase.properties.configuration.ingress.fqdn}'
output frontendUrl string = 'https://${frontend.properties.configuration.ingress.fqdn}'
