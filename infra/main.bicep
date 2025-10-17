targetScope = 'subscription'

import { getApplicationInsightsRegion, getLogAnalyticsRegion } from './util/region-selector.bicep'

@minLength(1)
@maxLength(64)
@description('Name of the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@description('References application or service contact information from a Service or Asset Management database')
param serviceManagementReference string = ''

@description('Comma-separated list of client application IDs to pre-authorize for accessing the MCP API (optional)')
param preAuthorizedClientIds string = ''

@description('OAuth2 delegated permissions for App Service Authentication login flow')
param delegatedPermissions array = ['User.Read']

@description('Token exchange audience for sovereign cloud deployments (optional)')
param tokenExchangeAudience string = ''

@minLength(1)
@description('Primary location for all resources')
@allowed([
  // 'australiaeast'
  // 'australiasoutheast'
  // 'brazilsouth'
  // 'canadacentral'
  // 'centralindia'
  // 'centralus'
  'eastasia'
  // 'eastus'
  // 'eastus2'
  'eastus2euap'
  // 'francecentral'
  // 'germanywestcentral'
  // 'italynorth'
  // 'japaneast'
  // 'koreacentral'
  // 'northcentralus'
  'northeurope'
  // 'norwayeast'
  // 'southafricanorth'
  // 'southcentralus'
  // 'southeastasia'
  // 'southindia'
  // 'spaincentral'
  // 'swedencentral'
  // 'uaenorth'
  // 'uksouth'
  // 'ukwest'
  'westcentralus'
  // 'westeurope'
  // 'westus'
  'westus2'
  // 'westus3'
])
@metadata({
  azd: {
    type: 'location'
  }
})
param location string
param mcpServiceName string = ''
param apiUserAssignedIdentityName string = ''
param applicationInsightsName string = ''
param appServicePlanName string = ''
param logAnalyticsName string = ''
param resourceGroupName string = ''
param storageAccountName string = ''
@description('Id of the user identity to be used for testing and debugging. This is not required in production. Leave empty if not needed.')
param principalId string = deployer().objectId


// NOTE: VNet integration and private endpoints are not supported with Windows Consumption (Y1 Dynamic) plans
// All storage and networking must use public endpoints with Azure-managed security

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }
var functionAppName = !empty(mcpServiceName) ? mcpServiceName : '${abbrs.webSitesFunctions}mcp-${resourceToken}'

// Convert comma-separated string to array for pre-authorized client IDs
var preAuthorizedClientIdsArray = !empty(preAuthorizedClientIds) ? map(split(preAuthorizedClientIds, ','), clientId => trim(clientId)) : []

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// User assigned managed identity to be used by the MCP function app to reach storage and other dependencies
// Assign specific roles to this identity in the RBAC module
module mcpUserAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = {
  name: 'mcpUserAssignedIdentity'
  scope: rg
  params: {
    location: location
    tags: tags
    name: !empty(apiUserAssignedIdentityName) ? apiUserAssignedIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}mcp-${resourceToken}'
  }
}

// Create a Standard App Service Plan for Windows Functions
module appServicePlan 'br/public:avm/res/web/serverfarm:0.1.1' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    sku: {
      name: 'S1'
      tier: 'Standard'
    }
    reserved: false
    location: location
    tags: tags
  }
}

// Entra ID application registration for MCP authentication (with predictable hostname)
module entraApp 'app/entra.bicep' = {
  name: 'entraApp'
  scope: rg
  params: {
    appUniqueName: '${functionAppName}-app'
    appDisplayName: 'MCP Authorization App'
    serviceManagementReference: serviceManagementReference
    functionAppHostname: '${functionAppName}.azurewebsites.net'
    preAuthorizedClientIds: preAuthorizedClientIdsArray
    managedIdentityClientId: mcpUserAssignedIdentity.outputs.clientId
    managedIdentityPrincipalId: mcpUserAssignedIdentity.outputs.principalId
    tags: tags
  }
}

// Define the configuration object locally to pass to the modules
var storageEndpointConfig = {
  enableBlob: true  // Required for AzureWebJobsStorage, .zip deployment, Event Hubs trigger and Timer trigger checkpointing
  enableQueue: true  // Required for Durable Functions and MCP trigger
  enableTable: false  // Required for Durable Functions and OpenAI triggers and bindings
  allowUserIdentityPrincipal: false   // Allow interactive user identity to access for testing and debugging
}

// Backing storage for Azure functions backend API
module storage 'br/public:avm/res/storage/storage-account:0.8.3' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true // needed for Files
    dnsEndpointType: 'Standard'
    publicNetworkAccess: 'Enabled' // Windows Consumption requires public access
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    blobServices: {
      containers: []  // Windows Consumption doesn't need deployment containers like Flex Consumption
    }
    minimumTlsVersion: 'TLS1_2'  // Enforcing TLS 1.2 for better security
    location: location
    tags: tags
    skuName: 'Standard_LRS'  // Standard performance with locally redundant storage
  }
}

module mcp './app/mcp.bicep' = {
  name: 'mcp'
  scope: rg
  params: {
    name: functionAppName
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.name
    appServicePlanId: appServicePlan.outputs.resourceId
    storageAccountName: storage.outputs.name
    enableBlob: storageEndpointConfig.enableBlob
    enableQueue: storageEndpointConfig.enableQueue
    enableTable: storageEndpointConfig.enableTable
    identityId: mcpUserAssignedIdentity.outputs.resourceId
    identityClientId: mcpUserAssignedIdentity.outputs.clientId
    preAuthorizedClientIds: preAuthorizedClientIdsArray
    appSettings: {
      // Reserved for additional app settings if needed
    }
    // Authorization parameters
    authClientId: entraApp.outputs.applicationId
    authIdentifierUri: entraApp.outputs.identifierUri
    authExposedScopes: entraApp.outputs.exposedScopes
    authTenantId: tenant().tenantId
    delegatedPermissions: delegatedPermissions
    tokenExchangeAudience: tokenExchangeAudience
  }
}

// Consolidated Role Assignments
module rbac 'app/rbac.bicep' = {
  name: 'rbacAssignments'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    appInsightsName: monitoring.outputs.name
    managedIdentityPrincipalId: mcpUserAssignedIdentity.outputs.principalId
    userIdentityPrincipalId: principalId
    enableBlob: storageEndpointConfig.enableBlob
    enableQueue: storageEndpointConfig.enableQueue
    enableTable: storageEndpointConfig.enableTable
    allowUserIdentityPrincipal: storageEndpointConfig.allowUserIdentityPrincipal
  }
}

// Monitor application with Azure Monitor - Log Analytics and Application Insights
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.11.1' = {
  name: '${uniqueString(deployment().name, location)}-loganalytics'
  scope: rg
  params: {
    name: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    location: getLogAnalyticsRegion(location)
    tags: tags
    dataRetention: 30
  }
}

module monitoring 'br/public:avm/res/insights/component:0.6.0' = {
  name: '${uniqueString(deployment().name, location)}-appinsights'
  scope: rg
  params: {
    name: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    location: getApplicationInsightsRegion(location)
    tags: tags
    workspaceResourceId: logAnalytics.outputs.resourceId
    disableLocalAuth: true
  }
}

// App outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.connectionString
output APPLICATIONINSIGHTS_LOCATION string = getApplicationInsightsRegion(location)
output LOGANALYTICS_LOCATION string = getLogAnalyticsRegion(location)
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP_NAME string = rg.name
output SERVICE_MCP_NAME string = mcp.outputs.SERVICE_MCP_NAME
output SERVICE_MCP_DEFAULT_HOSTNAME string = mcp.outputs.SERVICE_MCP_DEFAULT_HOSTNAME
output AZURE_FUNCTION_NAME string = mcp.outputs.SERVICE_MCP_NAME

// Entra App outputs (using the initial app for core properties)
output ENTRA_APPLICATION_ID string = entraApp.outputs.applicationId
output ENTRA_APPLICATION_OBJECT_ID string = entraApp.outputs.applicationObjectId
output ENTRA_SERVICE_PRINCIPAL_ID string = entraApp.outputs.servicePrincipalId
output ENTRA_IDENTIFIER_URI string = entraApp.outputs.identifierUri

// Authorization outputs
output AUTH_ENABLED bool = mcp.outputs.AUTH_ENABLED
output CONFIGURED_SCOPES string = mcp.outputs.CONFIGURED_SCOPES

// Pre-authorized applications
output PRE_AUTHORIZED_CLIENT_IDS string = preAuthorizedClientIds

// Entra App redirect URI outputs (using predictable hostname)
output CONFIGURED_REDIRECT_URIS array = entraApp.outputs.configuredRedirectUris
output AUTH_REDIRECT_URI string = entraApp.outputs.authRedirectUri
