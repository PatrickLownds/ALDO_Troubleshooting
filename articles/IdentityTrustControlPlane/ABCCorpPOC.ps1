<#
=================================================================================
README & DEPLOYMENT SCRIPT: AD DS, Enterprise CA, and AD FS for ABCCorp.Local POC
=================================================================================

OVERVIEW:
  This script automates the end-to-end deployment of Active Directory Domain Services 
  (AD DS), Active Directory Certificate Services (Enterprise CA), and Active Directory 
  Federation Services (AD FS) on a single Windows Server instance for your proof of concept.

VIRTUAL MACHINE PREREQUISITES & SIZING:
  • vCPUs: 4 vCPUs recommended for handling authentication tokens and IIS requests.
  • RAM: 8 GB to 16 GB (16 GB recommended for optimal headroom).
  • Storage: 60 GB to 100 GB on fast SSD storage.
  • Operating System: Windows Server 2022 updated to Oct 2026 or later. Vanilla install following defaults (enable RDP if required).
  • Network: Assign a static IPv4 address (do not use DHCP). Point primary DNS to 
    127.0.0.1 (loopback) or the server's own static IP.
  • Hostname: Set a permanent computer name before running the script e.g. AB-POC-ADCSFS01.

EXECUTION INSTRUCTIONS:
  1. Open PowerShell as an Administrator.
  2. Set script execution policy if needed: 
     Set-ExecutionPolicy Unrestricted -Scope Process -Force
  3. Run Blocks 1 through 3. The server will automatically reboot during Block 3.
  4. After the server reboots and you log back in, run Blocks 4 through 7.
=================================================================================
#>

# ===============================================================================
# BLOCK 1: CONFIGURATION & ENVIRONMENT VARIABLES
# ===============================================================================
$DomainName   = "ABCCorpALDOPOC.io"
$NetBiosName  = "ABCCorpALDOPOC"
$SafeModePass = (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force)
$FederationServiceDisplayName = "ABCCorp AD Federation Service"
$Fqdn         = "fs.$DomainName"


# ===============================================================================
# BLOCK 2: INSTALL AD DS FEATURE ONLY (Must happen BEFORE AD CS)
# ===============================================================================
Write-Host "=== BLOCK 2: Installing AD DS Feature ===" -ForegroundColor Cyan
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# [NOTE: Do not restart at this point or you will need to rerun the variables in block 1.]

# ===============================================================================
# BLOCK 3: AD DS FOREST PROMOTION (Triggers Server Reboot)
# ===============================================================================
Write-Host "=== BLOCK 3: Promoting Server to Domain Controller ===" -ForegroundColor Cyan
Import-Module ADDSDeployment
Install-ADDSForest `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainMode "WinThreshold" `
    -DomainName $DomainName `
    -DomainNetbiosName $NetBiosName `
    -ForestMode "WinThreshold" `
    -InstallDns:$true `
    -LogPath "C:\Windows\NTDS" `
    -NoRebootOnCompletion:$false `
    -SysvolPath "C:\Windows\SYSVOL" `
    -SafeModeAdministratorPassword $SafeModePass `
    -Force:$true

# [NOTE: The server will reboot automatically here. Resume execution after reboot. Ignore any WARNINGS.]


# ===============================================================================
# BLOCK 4: INSTALL REMAINING ROLES (AD CS & AD FS) POST-REBOOT
# ===============================================================================
Write-Host "=== BLOCK 4: Installing AD CS & AD FS Features ===" -ForegroundColor Cyan
Install-WindowsFeature -Name ADCS-Cert-Authority, ADFS-Federation -IncludeManagementTools


# ===============================================================================
# BLOCK 5: ACTIVE DIRECTORY CERTIFICATE SERVICES (ENTERPRISE CA) CONFIGURATION
# ===============================================================================
Write-Host "=== BLOCK 5: Configuring Active Directory Certificate Services (Enterprise CA) ===" -ForegroundColor Cyan
Install-AdcsCertificationAuthority `
    -CAType EnterpriseRootCA `
    -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
    -KeyLength 2048 `
    -HashAlgorithmName SHA256 `
    -ValidityPeriod Years `
    -ValidityPeriodUnits 5 `
    -Force


# ===============================================================================
# BLOCK 6: REQUESTING TRUSTED SSL CERTIFICATE FROM ENTERPRISE CA FOR AD FS
# ===============================================================================
Write-Host "=== BLOCK 6: Requesting SSL Certificate from Enterprise CA for AD FS ===" -ForegroundColor Cyan

$DomainName   = "ABCCorpALDOPOC.io"
$NetBiosName  = "ABCCorpALDOPOC"
$Fqdn         = "fs.$DomainName"

$CertReqFile = "$env:TEMP\adfs_cert.inf"
@"
[Version]
Signature="$Windows NT$"

[NewRequest]
Subject = "CN=$Fqdn"
Exportable = TRUE
KeyLength = 2048
KeySpec = 1
KeyUsage = 0xA0
MachineKeySet = True

[Extensions]
2.5.29.17 = "{text}dns=$Fqdn"

[RequestAttributes]
CertificateTemplate = WebServer
"@ | Out-File -FilePath $CertReqFile -Encoding ASCII

$ReqFile = "$env:TEMP\adfs_cert.req"
$CerFile = "$env:TEMP\adfs_cert.cer"

CertReq -new $CertReqFile $ReqFile
CertReq -submit $ReqFile $CerFile
CertReq -accept $CerFile

# Retrieve the thumbprint of the newly issued certificate
$Cert = Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object { $_.Subject -eq "CN=$Fqdn" } | Select-Object -First 1

if ($Cert) {
    Write-Host "Certificate successfully issued and imported. Thumbprint: $($Cert.Thumbprint)" -ForegroundColor Green
} else {
    Write-Error "Certificate was not found in the local store. Please check the CA submission status."
}

# ===============================================================================
# BLOCK 7: AD FS FARM DEPLOYMENT & BINDING
# ===============================================================================
Write-Host "=== BLOCK 7: Configuring Active Directory Federation Services (AD FS) ===" -ForegroundColor Cyan

$DomainName                   = "ABCCorpALDOPOC.io"
$Fqdn                         = "fs.$DomainName"
$FederationServiceDisplayName = "ABCCorp AD Federation Service"

# Ensure the certificate thumbprint is captured
$Cert = Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object { $_.Subject -eq "CN=$Fqdn" } | Select-Object -First 1

if (-not $Cert) {
    Write-Error "Could not find the SSL certificate for $Fqdn in Cert:\LocalMachine\My. Ensure Block 6 completed successfully."
} else {
    Install-AdfsFarm `
        -CertificateThumbprint $Cert.Thumbprint `
        -FederationServiceName $Fqdn `
        -FederationServiceDisplayName $FederationServiceDisplayName

    Write-Host "=== Deployment Complete Successfully ===" -ForegroundColor Green
}

# When prompted, enter your domain administrator username in UPN format (e.g. Administrator@ABCCorpALDOPOC.io or ABCCorpALDOPOC\Administrator) along with your domain password.