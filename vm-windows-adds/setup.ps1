[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true)]$DomainName,
    [Parameter(Mandatory=$true)]$DomainNetbiosName,
    [Parameter(Mandatory=$true)]$DSRM,
    [Parameter(Mandatory=$false)]$DC1JoinUser,
    [Parameter(Mandatory=$false)]$DC1JoinPass
)
try {
    # Sysconfig
    (Get-WmiObject -class "Win32_TSGeneralSetting" -Namespace root\cimv2\terminalservices -ComputerName $env:COMPUTERNAME -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(0)
    $size = (Get-PartitionSupportedSize -DriveLetter "C");Resize-Partition -DriveLetter "C" -Size $size.SizeMax -AsJob

    # Initial DC Forest
    if ($env:COMPUTERNAME -like "*adds0" -or $env:COMPUTERNAME -like "*adds1") {
        Write-Output "Setting up ADDS Forest $DomainName" | Out-File -FilePath setup.log -Append
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
        Import-Module ADDSDeployment
        Install-ADDSForest `
            -DomainName $DomainName `
            -DomainNetbiosName $DomainNetbiosName `
            -DomainMode "WinThreshold" `
            -ForestMode "WinThreshold" `
            -InstallDns `
            -DatabasePath "C:\Windows\NTDS" `
            -LogPath "C:\Windows\NTDS" `
            -SysvolPath "C:\Windows\SYSVOL" `
            -SafeModeAdministratorPassword (ConvertTo-SecureString $DSRM -AsPlainText -Force) `
            -NoRebootOnCompletion `
            -Force
        Write-Output "Successfully Promoted as a Primary DC" | Out-File -FilePath setup.log -Append
    }
    # Second DC
    else {
        Start-Sleep 600 # wait primary dc reboot
        Write-Output "Setting up ADDS Secondary Controller $DomainName" | Out-File -FilePath setup.log -Append
        $credObject = New-Object System.Management.Automation.PSCredential ("$DC1JoinUser@$DomainName", (ConvertTo-SecureString $DC1JoinPass -AsPlainText -Force))
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
        Import-Module ADDSDeployment
        Install-ADDSDomainController `
            -DomainName $DomainName `
            -InstallDns `
            -DatabasePath "C:\Windows\NTDS" `
            -LogPath "C:\Windows\NTDS" `
            -SysvolPath "C:\Windows\SYSVOL" `
            -Credential $credObject `
            -SafeModeAdministratorPassword (ConvertTo-SecureString $DSRM -AsPlainText -Force) `
            -Force
        Write-Output "Successfully Promoted as a Secondary DC" | Out-File -FilePath setup.log -Append
    }
    Write-Output "Server will restart" | Out-File -FilePath setup.log -Append
    Restart-Computer -Confirm:$false
}
catch {
    # get a generic error record
    [System.Management.Automation.ErrorRecord]$e = $_

    # retrieve information about runtime error
    $info = [PSCustomObject]@{
        Exception = $e.Exception.Message
        Reason    = $e.CategoryInfo.Reason
        Target    = $e.CategoryInfo.TargetName
        Script    = $e.InvocationInfo.ScriptName
        Line      = $e.InvocationInfo.ScriptLineNumber
        Column    = $e.InvocationInfo.OffsetInLine
    }
    #Write the error object
    $info | Out-File -FilePath setup.log -Append -NoClobber
    exit 99
}
exit 0