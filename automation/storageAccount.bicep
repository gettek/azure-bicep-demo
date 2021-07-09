param p_shortEnv string
param p_identity string

resource file_storage 'Microsoft.Storage/storageAccounts@2021-02-01' = {
    name                        : '${toLower(p_shortEnv)}sauks88'
    kind                        : 'StorageV2'
    location                    : resourceGroup().location
    sku                         : {
      name                    : 'Standard_ZRS'
    }
    properties                  : {
      allowBlobPublicAccess   : false
      allowSharedKeyAccess    : false
      largeFileSharesState    : 'Disabled'
      minimumTlsVersion       : 'TLS1_2'
      networkAcls             : {
          defaultAction       : 'Deny'
      }
      supportsHttpsTrafficOnly: true
    }
}

var storageContributorRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab')

resource hwBlobStorageContributor 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(file_storage.id, storageContributorRole)
  scope: file_storage
  properties: {
    roleDefinitionId: storageContributorRole
    principalId: p_identity
    description: 'Hybrid Worker Storage Contributor'
  }
}
