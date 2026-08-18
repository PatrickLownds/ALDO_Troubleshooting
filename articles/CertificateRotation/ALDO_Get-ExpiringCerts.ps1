# Ensure the PSPKI module is installed and loaded
if (-not (Get-Module -ListAvailable -Name PSPKI)) {
    Install-Module -Name PSPKI -Scope CurrentUser -AllowClobber -Force
}
Import-Module PSPKI -ErrorAction Stop

# Set to query AD CS for certificates expiring within the next 30 days
$ThresholdDays = 30
$ExpirationDate = (Get-Date).AddDays($ThresholdDays)

# Ensure the output directory exists
$ReportPath = "C:\Reports"
if (-not (Test-Path -Path $ReportPath)) {
    New-Item -ItemType Directory -Path $ReportPath | Out-Null
}

# Auto-discover CA and export matching issued certificates
Get-CertificationAuthority | 
  Get-IssuedRequest | 
  Where-Object { $_.NotAfter -le $ExpirationDate -and $_.NotAfter -ge (Get-Date) } | 
  Select-Object RequestID, CommonName, NotAfter, SerialNumber | 
  Export-Csv -Path "$ReportPath\ExpiringCertificates.csv" -NoTypeInformation