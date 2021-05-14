# Deploy Windows Servers for Active Directory Domain Services

Modified from the main Bicep repo [101-vm-simple-windows](https://github.com/Azure/bicep/tree/main/docs/examples/101/vm-simple-windows)

- [Deploy Windows Servers for Active Directory Domain Services](#deploy-windows-servers-for-active-directory-domain-services)
  - [KeyVault Expiry Dates](#keyvault-expiry-dates)
  - [Encoding the Custom Script](#encoding-the-custom-script)
    - [Decoding the Custom script resource with Parameters](#decoding-the-custom-script-resource-with-parameters)
  - [Single line AZ deployment](#single-line-az-deployment)
  - [Function to generate a random password](#function-to-generate-a-random-password)

## KeyVault Expiry Dates

KeyVault objects such as Secrets and Keys accept only UNIX Time for their Start (nbf) and Expiry (exp) dates in seconds since 1970-01-01T00:00:00Z.
This can be obtained with PowerShell in the example below to get the time 1 Year from now:

```powershell
$secretExpiry = (Get-Date(Get-Date).AddDays(365).ToUniversalTime() -UFormat "%s")
> 1652448713
```

## Encoding the Custom Script

Created a Base64 encoded value of the custom script will avoid the need for storing/obtaining from another source such Storage Account. This will be decoded back once the extension executes locally on the vm.

```powershell
$virtualMachineExtensionCustomScriptEncoded = ([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($(Get-Content -Path .\setup.ps1 -Raw))))
```

### Decoding the Custom script resource with Parameters

```bicep
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
```

## Single line AZ deployment

```bash
$rgName = "rg-dev-uks-hub-adds"
$secretExpiry = (Get-Date(Get-Date).AddDays(365).ToUniversalTime() -UFormat "%s")
$virtualMachineExtensionCustomScriptEncoded = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($(Get-Content setup.ps1 -Raw)))
$virtualMachineAdminPassword = New-RandomPassword -MinimumPasswordLength 15 -MaximumPasswordLength 20 -NumberOfAlphaNumericCharacters 6
$addsDsrmPassword = New-RandomPassword -MinimumPasswordLength 15 -MaximumPasswordLength 20 -NumberOfAlphaNumericCharacters 6

az deployment group create -f main.bicep -g $rgName --parameters virtualMachineExtensionCustomScriptEncoded=$virtualMachineExtensionCustomScriptEncoded secretExpiry=$secretExpiry virtualMachineAdminPassword=$virtualMachineAdminPassword addsDsrmPassword=$addsDsrmPassword
```

> **Note:** Some of the parameters are stored in the actual template to simplify testing but these should only be parsed via the deployment pipelines as extra parameter values seen above.


## Function to generate a random password

Taken from: [How to Create a Random Password Generator](https://adamtheautomator.com/random-password-generator/)

```powershell
function New-RandomPassword {
    param(
        [Parameter()][int]$MinimumPasswordLength = 5,
        [Parameter()][int]$MaximumPasswordLength = 10,
        [Parameter()][int]$NumberOfAlphaNumericCharacters = 5,
        [Parameter()][switch]$ConvertToSecureString
    )
    
    Add-Type -AssemblyName 'System.Web'
    $length = Get-Random -Minimum $MinimumPasswordLength -Maximum $MaximumPasswordLength
    $password = [System.Web.Security.Membership]::GeneratePassword($length,$NumberOfAlphaNumericCharacters)
    if ($ConvertToSecureString.IsPresent) {
        ConvertTo-SecureString -String $password -AsPlainText -Force
    } else {
        $password
    }
}
```
