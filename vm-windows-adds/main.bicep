// Resource name
param name string = 'bctst'
// Resource suffix
param suffix string = 'adds'
// Resource location
param location string = resourceGroup().location

// VM secret and encryption key expiry dates. Unix time (in seconds) 1 year from now
// Use PowerShell to obtain timestamp: (Get-Date(Get-Date).AddDays(365).ToUniversalTime() -UFormat "%s")
param secretExpiry int = 1652448713

// Unique DNS Name for the Public IP used to access the Virtual Machine.
param publicIpDnsLabel string = 'ipbctst'

// CIDR notation of the Virtual Networks.
param virtualNetworkAddressPrefix string = '10.0.0.0/16'
// CIDR notation of the Virtual Network Subnets.
param virtualNetworkSubnetPrefix string = '10.0.0.0/24'

// The number of Virtual Machines for this service.
param virtualMachineCount int = 2

// Size of the Virtual Machine.
@allowed([
  'Standard_D2s_v3'
  'Standard_D4s_v3'
  'Standard_D8s_v3'
  'Standard_B2ms'
])
param virtualMachineSize string = 'Standard_D8s_v3'

// The Virtual Machine Operating Sytem Values.
@allowed([
  'Server2012R2'
  'Server2016'
  'Server2019'
])
param operatingSystem string = 'Server2019'

var operatingSystemValues = {
  Server2012R2: {
    PublisherValue: 'MicrosoftWindowsServer'
    OfferValue: 'WindowsServer'
    SkuValue: '2012-R2-Datacenter'
  }
  Server2016: {
    PublisherValue: 'MicrosoftWindowsServer'
    OfferValue: 'WindowsServer'
    SkuValue: '2016-Datacenter'
  }
  Server2019: {
    PublisherValue: 'MicrosoftWindowsServer'
    OfferValue: 'WindowsServer'
    SkuValue: '2019-Datacenter'
  }
}

// Username for the Virtual Machine.
param virtualMachineAdminUsername string = 'nomen.nescio'

// Password for the Virtual Machine.
@secure()
param virtualMachineAdminPassword string = '$$EZN9voKC0y*R*RVO'

// ADDS Custom Script Parameters
param domainName string = 'addstst.com'
param domainNetBiosName string = 'ADDSTST'
@secure()
param addsDsrmPassword string = 'j9$ZRM13oZmxl7YksQ'

// The Base64 encoded PowerShell Custom Script
@secure()
param virtualMachineExtensionCustomScriptEncoded string = base64((loadTextContent('./setup.ps1')))

// Resource naming conventions
var metadata = {
  longName: '{0}-${name}-${(suffix ?? '') == '' ? '' : suffix}'
  shortName: '{0}${replace(name, '-', '')}${(suffix ?? '') == '' ? '' : suffix}'
}

// Key Vault
var keyVault = {
  name: replace(metadata.shortName, '{0}', 'kv')
  location: location
}

resource kv 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVault.name
  location: keyVault.location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'premium'
    }
    enabledForDeployment: false
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    softDeleteRetentionInDays: 14
    enablePurgeProtection: true
    accessPolicies: []
  }
}

// Stroage Account
var storageAccount = {
  name: replace(metadata.shortName, '{0}', 'sa')
  location: location
}

resource st 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccount.name
  location: storageAccount.location
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
  }
  sku: {
    name: 'Standard_LRS'
  }
}

// Network Security Group
var networkSecurityGroup = {
  name: replace(metadata.longName, '{0}', 'nsg')
  location: location
  securityRules: [
    {
      name: 'default-allow-3389'
      properties: {
        priority: 1000
        access: 'Allow'
        direction: 'Inbound'
        protocol: 'TCP'
        sourcePortRange: '*'
        sourceAddressPrefix: '*'
        destinationAddressPrefix: '*'
        destinationPortRange: 3389
      }
    }
  ]
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2020-06-01' = {
  name: networkSecurityGroup.name
  location: networkSecurityGroup.location
  properties: {
    securityRules: networkSecurityGroup.securityRules
  }
}

// Virtual Network
var subnetName = 'default'
var virtualNetwork = {
  name: replace(metadata.longName, '{0}', 'vnet')
  location: location
  addressPrefixes: [
    virtualNetworkAddressPrefix
  ]
}

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: virtualNetwork.name
  location: virtualNetwork.location
  properties: {
    addressSpace: {
      addressPrefixes: virtualNetwork.addressPrefixes
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: virtualNetworkSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

// Public IP
var publicIp = {
  name: replace(metadata.longName, '{0}', 'pip')
  location: location
}

resource pip 'Microsoft.Network/publicIPAddresses@2020-07-01' = [for i in range(0, virtualMachineCount): {
  name: '${publicIp.name}${i + 1}'
  location: publicIp.location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: '${(publicIpDnsLabel ?? '') == '' ? replace(metadata.shortName, '{0}', 'vm') : publicIpDnsLabel}${i + 1}'
    }
  }
  zones: [
    '${i + 1}'
  ]
}]

// Network Interface
var networkInterface = {
  name: replace(metadata.longName, '{0}', 'nic')
  location: location
}

resource networkInterfaces 'Microsoft.Network/networkInterfaces@2020-06-01' = [for i in range(0, virtualMachineCount): {
  name: '${networkInterface.name}${i + 1}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: resourceId('Microsoft.Network/publicIPAddresses', '${publicIp.name}${i + 1}')
          }
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
    enableIPForwarding: false
  }
  dependsOn: [
    pip
  ]
}]

// Virtual Machine Variables
var virtualMachine = {
  name: replace(metadata.shortName, '{0}', 'vm')
  location: location

  vmSize: virtualMachineSize
  vmComputerName: replace(metadata.shortName, '{0}', 'vm')
  vmAdminUsername: virtualMachineAdminUsername
  vmAdminPassword: virtualMachineAdminPassword
  vmAdminPasswordKeyVaultSecretExpiry: secretExpiry

  vmImagePublisher: operatingSystemValues[operatingSystem].PublisherValue
  vmImageOffer: operatingSystemValues[operatingSystem].OfferValue
  vmImageSku: operatingSystemValues[operatingSystem].SkuValue

  vmOSDiskName: replace(metadata.longName, '{0}', 'osdisk')
  vmOSDiskSize: 256

  vmDataDisks: []

  vmDiskEncryptionSetName: replace(metadata.shortName, '{0}', 'des')
  vmDiskEncryptionSetKeyExpiry: secretExpiry

  vmWindowsConfiguration: {
    provisionVMAgent: true
    enableAutomaticUpdates: true
    timeZone: 'GMT Standard Time'
  }
}

// Disk Encryption Set
resource des 'Microsoft.Compute/diskEncryptionSets@2020-12-01' = {
  name: virtualMachine.vmDiskEncryptionSetName
  location: virtualMachine.location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    activeKey: {
      sourceVault: {
        id: kv.id
      }
      keyUrl: kvdeskey.properties.keyUriWithVersion
    }
  }
}

// KeyVault Access Policy for Disk Encryption Set Key
resource kvap 'Microsoft.KeyVault/vaults/accessPolicies@2019-09-01' = {
  name: '${kv.name}/replace'
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: des.identity.principalId
        permissions: {
          keys: [
            'create'
            'decrypt'
            'delete'
            'encrypt'
            'get'
            'sign'
            'unwrapKey'
            'verify'
            'wrapKey'
          ]
        }
      }
    ]
  }
}

// KeyVault Disk Encryption Set Key
resource kvdeskey 'Microsoft.KeyVault/vaults/keys@2019-09-01' = {
  name: '${kv.name}/${virtualMachine.vmDiskEncryptionSetName}'
  properties: {
    attributes: {
      exp: virtualMachine.vmDiskEncryptionSetKeyExpiry
    }
    kty: 'RSA'
    keySize: 2048
    keyOps: [
      'decrypt'
      'encrypt'
      'sign'
      'unwrapKey'
      'verify'
      'wrapKey'
    ]
  }
}

// Virtual Machine Admin Password KeyVault Secret
resource kvsecvmpass 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${kv.name}/${virtualMachine.name}'
  properties: {
    value: virtualMachine.vmAdminPassword
    attributes: {
      exp: virtualMachine.vmAdminPasswordKeyVaultSecretExpiry
    }
  }
}

// Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = [for i in range(0, virtualMachineCount): {
  name: '${virtualMachine.name}${i + 1}'
  location: virtualMachine.location
  properties: {
    hardwareProfile: {
      vmSize: virtualMachine.vmSize
    }
    osProfile: {
      computerName: '${virtualMachine.vmComputerName}${i + 1}'
      adminUsername: virtualMachine.vmAdminUsername
      adminPassword: virtualMachine.vmAdminPassword
      windowsConfiguration: {
        provisionVMAgent: virtualMachine.vmWindowsConfiguration.provisionVMAgent
        enableAutomaticUpdates: virtualMachine.vmWindowsConfiguration.enableAutomaticUpdates
        timeZone: virtualMachine.vmWindowsConfiguration.timeZone
      }
    }
    storageProfile: {
      imageReference: {
        publisher: virtualMachine.vmImagePublisher
        offer: virtualMachine.vmImageOffer
        sku: virtualMachine.vmImageSku
        version: 'latest'
      }
      osDisk: {
        name: '${virtualMachine.vmOSDiskName}${i + 1}'
        diskSizeGB: virtualMachine.vmOSDiskSize
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          diskEncryptionSet: {
            id: des.id
          }
        }
      }
      dataDisks: virtualMachine.vmDataDisks
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', '${networkInterface.name}${i + 1}')
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: st.properties.primaryEndpoints.blob
      }
    }
  }
  zones: [
    '${i + 1}'
  ]
  identity: {
    type: 'SystemAssigned'
  }
  dependsOn: [
    networkInterfaces
    kvap
    kvdeskey
  ]
}]

// Virtual Machine Extensions - Custom Script
resource vmext 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = [for (name, i) in range(0, virtualMachineCount): {
  name: '${vm[i].name}/setup'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: 'Powershell -command "[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("\'"${virtualMachineExtensionCustomScriptEncoded}"\'")) | Out-File -filepath setup.ps1" && powershell -ExecutionPolicy Unrestricted -File setup.ps1 ${domainName} ${domainNetBiosName} ${addsDsrmPassword} ${virtualMachineAdminUsername} ${virtualMachineAdminPassword}'
    }
  }
}]
