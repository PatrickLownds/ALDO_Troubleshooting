# Ensure the PSPKI module is installed and loaded
if (-not (Get-Module -ListAvailable -Name PSPKI)) {
    Install-Module -Name PSPKI -Scope CurrentUser -AllowClobber -Force
}
Import-Module PSPKI -ErrorAction Stop

# Auto-discover the active CA from Active Directory and query issued requests
Get-CertificationAuthority | Get-IssuedRequest