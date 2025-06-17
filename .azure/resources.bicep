param location string
param azureDevOpsOrgName string
param tags object = {}

// Log Analytics workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  scope: resourceGroup('80188524-4199-4293-8e33-7ba33daa0f2a', 'rg-logs')
  name: 'log-enterprise-eastus2'
}

// Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  scope: resourceGroup('80188524-4199-4293-8e33-7ba33daa0f2a', 'containers-core')
  name: 'hireground'
}

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'ado-mcp-server'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'adomcpvault'
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enabledForTemplateDeployment: true
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: false
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// User-assigned managed identity
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-ado-mcp'
  location: location
  tags: tags
}

// Role assignment for ACR Pull
module acrPullRole 'br/hireground:resource-role-assignment:2024-06-04' = {
  scope: subscription()
  name: 'acr-pull-role'
  params: {
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    resourceId: containerRegistry.id
    roles: [
      'AcrPull'
    ]
  }
}

// Container App Environment
resource containerAppEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'cae-devops-eastus2'
  location: location
  tags: tags
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

// Key Vault secret for container registry password
resource registrySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'registry-password'
  properties: {
    value: containerRegistry.listCredentials().passwords[0].value
  }
  dependsOn: [
    keyVaultRoles
  ]
}

// Container App
resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ado-mcp-server-eus2'
  location: location
  tags: union(tags, { 'azd-service-name': 'web' })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    environmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 3000
        transport: 'http'
        corsPolicy: {
          allowedOrigins: ['*']
          allowedMethods: ['*']
          allowedHeaders: ['*']
          allowCredentials: false
        }
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: userAssignedIdentity.id
        }
      ]
      secrets: [
        {
          name: 'appinsights-connection-string'
          value: applicationInsights.properties.ConnectionString
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'azure-devops-mcp'
          image: '${containerRegistry.properties.loginServer}/azure-devops-mcp:latest'
          env: [
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              secretRef: 'appinsights-connection-string'
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: userAssignedIdentity.properties.clientId
            }
            {
              name: 'AZURE_TENANT_ID'
              value: subscription().tenantId
            }
            {
              name: 'AZURE_SUBSCRIPTION_ID'
              value: subscription().subscriptionId
            }
            {
              name: 'AZURE_ORGANIZATION_NAME'
              value: azureDevOpsOrgName
            }
            {
              name: 'PORT'
              value: '3000'
            }
            {
              name: 'NODE_ENV'
              value: 'production'
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }  }
  dependsOn: [
    acrPullRole
    keyVaultRoles
  ]
}

// Key Vault RBAC role assignments
// Grant the managed identity Key Vault Secrets User and Key Vault Secrets Officer roles for reading and managing secrets
module keyVaultRoles 'br/hireground:resource-role-assignment:2024-06-04' = {
  scope: subscription()
  name: 'key-vault-user-roles'
  params: {
    resourceId: keyVault.id
    principalId: userAssignedIdentity.properties.principalId
    roles: [
      'Key Vault Secrets User'
      'Key Vault Secrets Officer'
    ]
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = applicationInsights.properties.ConnectionString
output AZURE_CLIENT_ID string = userAssignedIdentity.properties.clientId
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = containerAppEnv.id
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.properties.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.name
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.properties.vaultUri
output AZURE_KEY_VAULT_NAME string = keyVault.name
output SERVICE_WEB_ENDPOINT_URL string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output SERVICE_WEB_IMAGE_NAME string = '${containerRegistry.properties.loginServer}/azure-devops-mcp:latest'
