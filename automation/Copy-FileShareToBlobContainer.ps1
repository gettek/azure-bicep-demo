<#
.DESCRIPTION
A Runbook example which continuously check for files and directories changes in recursive mode
for a specific Azure File Share and then copy data to blob container by leveraging AzCopy tool
which is running in a Container inside an Azure Container Instances using Service Principal in Azure AD.

.NOTES
Filename : Copy-FileShareToBlobContainer
Author   : Charbel Nemnom
Version  : 1.1
Date     : 13-January-2021
Updated  : 13-April-2021

.LINK
To provide feedback or for further assistance please visit:
https://charbelnemnom.com 
#>

Param (
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [String] $AzureSubscriptionId,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [String] $storageAccountRG,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [String] $storageAccountName,    
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [String] $storageContainerName,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [String] $storageFileShareName
)

$connectionName = "AzureRunAsConnection"

Try {
    #! Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName
    Write-Output "Logging in to Azure..."
    Connect-AzAccount -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
}
Catch {
    If (!$servicePrincipalConnection) {
        $ErrorMessage = "Connection $connectionName not found..."
        throw $ErrorMessage
    }
    Else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

Select-AzSubscription -SubscriptionId $AzureSubscriptionId

# Get Storage Account Key
$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $storageAccountRG -AccountName $storageAccountName).Value[0]

# Set AzStorageContext
$destinationContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey

# Generate Container SAS URI Token which is valid for 30 minutes ONLY with read and write permission
$blobContainerSASURI = New-AzStorageContainerSASToken -Context $destinationContext `
    -ExpiryTime(get-date).AddSeconds(1800) -FullUri -Name $storageContainerName -Permission rw

# Generate File Share SAS URI Token which is valid for 30 minutes ONLY with read and list permission
$fileShareSASURI = New-AzStorageShareSASToken -Context $destinationContext `
    -ExpiryTime(get-date).AddSeconds(1800) -FullUri -ShareName $storageFileShareName -Permission rl

# Create azCopy syntax command
$ContainerSASURI = "'" + $blobContainerSASURI + "'"
$shareSASURI = "'" + $fileShareSASURI + "'"
$command = "azcopy " + "copy " + $ShareSASURI + " " + $ContainerSASURI + " --recursive"

# Create Azure Container Instance and run the AzCopy job
# The container image (peterdavehello/azcopy:latest) is publicly available on Docker Hub and has the latest AzCopy version installed
# You could also create your own private container image and use it instead
# When you create a new container instance, the default compute resources are set to 1vCPU and 1.5GB RAM
# We recommend starting with 2 vCPU and 4 GB memory for large file shares (E.g. 3TB)
# You may need to adjust the CPU and memory based on the size and churn of your file share
New-AzContainerGroup -ResourceGroupName $storageAccountRG `
    -Name azcopyjob -image peterdavehello/azcopy:latest -OsType Linux `
    -Cpu 2 -MemoryInGB 4 -Command $command `
    -RestartPolicy never

Write-Output ("")