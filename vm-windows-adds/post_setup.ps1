[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]$EnvName,
    [Parameter(Mandatory = $false)]$DomainName,
    [Parameter(Mandatory = $false)]$DomainNetbiosName,
    [Parameter(Mandatory = $false)]$DNSFZ,
    [Parameter(Mandatory = $false)]$DNSFZ_IPs
)

Import-Module -Name DnsServer

try {
    Add-DnsServerPrimaryZone -Name "$EnvName.$DNSFZ" -ReplicationScope "Forest" -PassThru
}
catch { Write-Host "Couldn't add Zone: $_" }

# Set External DNS Forwarder
$forwarderIP = "167.72.111.11"
$currentIP = (Get-DnsServerForwarder).IPAddress.IPAddressToString
if (!$currentIP ) {
    Write-Host "DNS Forwarder IP $forwarderIP"
    Add-DnsServerForwarder -IPAddress $forwarderIP -PassThru
}
elseif ($currentIP -ne $forwarderIP) {
    Write-Host "Replacing DNS Forwarder IP $currentIP with $forwarderIP"
    Remove-DnsServerForwarder -IPAddress $currentIP -Force
    Add-DnsServerForwarder -IPAddress $forwarderIP -PassThru
}

# Set Conditional DNS Forwarder Zones
$DNSFZ_IPs = $DNSFZ_IPs.Split(",")
Write-Host "DNS Forwarder Zone $DNSFZ"
try {
    Add-DnsServerConditionalForwarderZone -Name $DNSFZ -MasterServers $DNSFZ_IPs -PassThru
}
catch {
    Set-DnsServerConditionalForwarderZone -Name $DNSFZ -MasterServers $DNSFZ_IPs -PassThru -ErrorAction SilentlyContinue
}

# Create initial OU Structure
Import-Module ActiveDirectory

$OU = [ordered]@{
    "Regions" = ""; "United Kingdom" = "OU=Regions,"; "Admins" = "OU=United Kingdom,OU=Regions,"
    "AADC" = ""; "Sync" = "OU=AADC,"; "Test" = "OU=Sync,OU=AADC,"
}
$OU.Keys | ForEach-Object {
    $Key = $_
    Write-Host "Adding Organisational Unit $Key"
    try {
        New-ADOrganizationalUnit -Name $Key -Path ($OU.$Key + "DC=$DomainNetbiosName,DC=com") -ProtectedFromAccidentalDeletion $False
    }
    catch { Write-host "OU Exists: $_" }
}

# Create Groups
New-ADGroup `
    -Name "UK Admins" `
    -SamAccountName UKAdmins `
    -GroupCategory Security `
    -GroupScope Global `
    -DisplayName "UK Administrators" `
    -Path "OU=Admins,OU=United Kingdom,OU=Regions,DC=$DomainNetbiosName,DC=com" `
    -Description "Members of this group are RODC Administrators"

# Create Users (https://docs.microsoft.com/en-us/powershell/module/activedirectory/new-aduser?view=windowsserver2019-ps)
# New-ADUser
