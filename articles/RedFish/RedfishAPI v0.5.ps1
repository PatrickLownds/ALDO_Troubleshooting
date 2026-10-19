# ==============================================================================
# HPE ProLiant Gen12 BIOS Configuration via iLO Redfish API
# Target: Set Power Regulator to Maximum Performance & Enable Secure Boot
# Compatible with Windows PowerShell 5.1 & PowerShell 7+
# Server: Powered Off
# ==============================================================================

# --- Bypass SSL/TLS Certificate Validation (Safe Re-run) ---
if (-not ([System.Management.Automation.PSTypeName]'TrustAllCertsPolicy').Type) {
Add-Type @"
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
}
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# --- Step 1: Define iLO Credentials & Generate Auth Header ---
$iLOIP    = "192.168.1.66"
$Username = "admin"
$Password = "GLPlatform25!"

$base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${Password}"))
$headers    = @{
    "Authorization" = "Basic $base64Auth"
    "Content-Type"  = "application/json"
}

# --- Step 2: Verify Network Reachability ---
Write-Host "Checking reachability to iLO at $iLOIP..." -ForegroundColor Cyan
Test-Connection -ComputerName $iLOIP -Count 2

# --- Step 3: Query Current BIOS Attributes ---
Write-Host "`nQuerying current BIOS settings from Redfish endpoint..." -ForegroundColor Cyan
$uri          = "https://$iLOIP/redfish/v1/Systems/1/Bios/"
$biosSettings = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

# Clean count output (stores count as int explicitly)
$attrCount = @($biosSettings.Attributes.PSObject.Properties).Count
Write-Host "Total BIOS attributes returned: $attrCount" -ForegroundColor Green

Write-Host "Current Power Regulator: $($biosSettings.Attributes.PowerRegulator)" -ForegroundColor White

# --- Step 4: Stage Pending BIOS Configuration Updates ---
Write-Host "`nStaging pending BIOS configuration updates..." -ForegroundColor Cyan
$updateUri = "https://$iLOIP/redfish/v1/Systems/1/Bios/Settings/"
$body = @{
    Attributes = @{
        PowerRegulator = "StaticHighPerf"  # Exact payload value required by HPE Gen12
    }
} | ConvertTo-Json

try {
    $patchResponse = Invoke-RestMethod -Uri $updateUri -Headers $headers -Method Patch -Body $body
    Write-Host "BIOS updates successfully staged in iLO pending registry." -ForegroundColor Green
} catch {
    Write-Host "Error staging BIOS update: $_" -ForegroundColor Red
}

# Configure Secure Boot via dedicated HPE Redfish SecureBoot endpoint
Write-Host "`nConfiguring Secure Boot..." -ForegroundColor Cyan
$secureBootUri = "https://$iLOIP/redfish/v1/Systems/1/SecureBoot/"
$secureBootBody = @{
    SecureBootEnable = $true
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri $secureBootUri -Headers $headers -Method Patch -Body $secureBootBody
    Write-Host "Secure Boot set to Enabled." -ForegroundColor Green
} catch {
    Write-Host "Secure Boot update note/warning: $_" -ForegroundColor Yellow
}

# --- Step 5: Reboot Server to Apply Pending Changes ---
Write-Host "`nInitiating system reset to apply pending changes..." -ForegroundColor Cyan
$resetUri = "https://$iLOIP/redfish/v1/Systems/1/Actions/ComputerSystem.Reset"
$resetBody = @{
    ResetType = "ForceRestart"  # ForceRestart bypasses OS state issues
} | ConvertTo-Json

try {
    $resetResponse = Invoke-RestMethod -Uri $resetUri -Headers $headers -Method Post -Body $resetBody
    Write-Host "Restart command successfully processed. The server will now reboot and apply pending BIOS changes." -ForegroundColor Green
} catch {
    Write-Host "Reset Action Error Detail:" -ForegroundColor Red
    if ($_.Exception.Response) {$reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())$errBody = $reader.ReadToEnd() \vert{} ConvertFrom-Json$errBody.'@Message.ExtendedInfo' | ForEach-Object { Write-Host "iLO Detail: $($_.Message)" -ForegroundColor Red }
    } else {
        Write-Host $_ -ForegroundColor Red
    }
}