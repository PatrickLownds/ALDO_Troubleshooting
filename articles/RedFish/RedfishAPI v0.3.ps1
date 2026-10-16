# ==============================================================================
# HPE ProLiant Gen12 BIOS Configuration via iLO Redfish API
# Target: Set Power Regulator to Maximum Performance and Enable Secure Boot
# Compatible with Windows PowerShell 5.1 & PowerShell 7+
# ==============================================================================

# --- Bypass SSL/TLS Certificate Validation (Windows PowerShell 5.1 Fix) ---
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# --- Step 1: Define iLO Credentials & Generate Auth Header ---
$iLOIP = "192.168.1.66"
$Username = "admin"
$Password = "GLPlatform25!"

$base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${Password}"))
$headers = @{
    "Authorization" = "Basic $base64Auth"
    "Content-Type"  = "application/json"
}

# --- Step 2: Verify Network Reachability ---
Write-Host "Checking reachability to iLO at $iLOIP..." -ForegroundColor Cyan
Test-Connection -ComputerName $iLOIP -Count 2

# --- Step 3: Query & Verify Current BIOS Attributes ---
Write-Host "Querying current BIOS settings from Redfish endpoint..." -ForegroundColor Cyan
$uri = "https://$iLOIP/redfish/v1/Systems/1/Bios/"
$biosSettings = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

# Verification checks (Fixed for PSCustomObject)
Write-Host "Total BIOS attributes returned: $($biosSettings.Attributes.PSObject.Properties.Count)" -ForegroundColor Green
Write-Host "Sample current attributes (first 10):" -ForegroundColor Yellow
$biosSettings.Attributes.PSObject.Properties | Select-Object -First 10 -Property Name, Value

# Query specific key attributes directly
Write-Host "Current Boot Mode: $($biosSettings.Attributes.BootMode)" -ForegroundColor White
Write-Host "Current Power Regulator: $($biosSettings.Attributes.PowerRegulator)" -ForegroundColor White
Write-Host "Current Secure Boot Status: $($biosSettings.Attributes.SecureBoot)" -ForegroundColor White

# --- Step 4: Stage Pending BIOS Updates (Max Performance & Secure Boot) ---
Write-Host "Staging pending BIOS configuration updates..." -ForegroundColor Cyan
$updateUri = "https://$iLOIP/redfish/v1/Systems/1/Bios/Settings/"
$body = @{
    Attributes = @{
        PowerRegulator = "StaticHighPerformance"
        SecureBoot     = "Enabled"
    }
} | ConvertTo-Json

$patchResponse = Invoke-RestMethod -Uri $updateUri -Headers $headers -Method Patch -Body $body
Write-Host "BIOS updates successfully staged in iLO registry." -ForegroundColor Green

# --- Step 5: Reboot Server to Apply Pending Changes ---
Write-Host "Initiating graceful restart to apply BIOS changes..." -ForegroundColor Cyan
$resetUri = "https://$iLOIP/redfish/v1/Systems/1/Actions/ComputerSystem.Reset/"
$resetBody = @{
    ResetType = "GracefulRestart"
} | ConvertTo-Json

Invoke-RestMethod -Uri $resetUri -Headers $headers -Method Post -Body $resetBody
Write-Host "Restart command sent. The server will now reboot and apply the changes." -ForegroundColor Green