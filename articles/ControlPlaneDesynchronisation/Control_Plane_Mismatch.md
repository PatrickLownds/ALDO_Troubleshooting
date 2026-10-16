# Azure Local Deployment Mismatch & Control Plane Desynchronisation

**Symptom:** The Azure Portal displays a banner error stating:

_"Your system is validated but deployment failed. To see the details click view more"._

Under Essentials, the **Azure Local connection** status reflects:

_"Deployment failed—Connected an hour ago"_

#### Figure 1: Control Plane Desynchronisation
![Control Plane Desynchronisation](https://raw.githubusercontent.com/PatrickLownds/ALDO_Troubleshooting/main/articles/ControlPlaneDesynchronisation/ControlPlane.png)

**Impact:** Although the underlying cluster and hardware pass validation, the control plane state in the portal reflects a deployment failure. This is a known cosmetic/synchronisation disconnect between the local lifecycle manager / control plane and the cloud relay.

**Root Cause Analysis**

1. **Control Plane / Portal State Desynchronisation:** The local orchestration engine completes deployment or validation steps, but the signalling response to the portal state engine times out or fails to push a final completion status.
2. **Service State Drift:** The local Life Cycle Manager service (LCMController) or Hybrid Instance Metadata Service (HIMDS) on the seed node fails to send an updated status payload back to the management relay.

**Executed & Recommended Troubleshooting Workflow**

**Phase 1: Local Service Refresh (Non-Disruptive)**

Execute on the primary/seed node via an elevated PowerShell session to force the local controller to resynchronise its state with the portal:

```
# 1. Verify service health
Get-Service HIMDS
Get-Service LCMController
# 2. Restart the Life Cycle Manager controller service to trigger a state update
Restart-Service LCMController -Verbose
# 3. Confirm service status
Get-Service LCMController
```

**Phase 2: Local Deployment Log Verification**

To confirm whether the deployment succeeded locally despite the portal warning, inspect the local deployment logs on the seed node:

```
# Check Cloud Deployment log directory
Get-ChildItem -Path "C:\CloudDeployment\Logs" -Filter "CloudDeployment*.log" |
    Sort-LastWriteTime -Descending |
    Select-Object -First 5
```

Look for completion signatures or specific orchestration step failures to rule out a genuine local engine halt.

**Phase 3: Deployment and LCM Log Collection**

Microsoft requested all deployment and LCM logs for troubleshooting without date restrictions into a single, clean ZIP archive on the seed node, run the following PowerShell script directly on the host.

```
# Define target folder and static ZIP output path
$targetDir = "C:\temp\AldoLogs"
$destinationZip = "$targetDir\AzureLocal_DeploymentLogs.zip"
# Ensure the destination directory exists
if (-not (Test-Path $targetDir)) {
    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
}
# Compress Cloud Deployment Logs directly without timestamp naming
if (Test-Path "C:\CloudDeployment\Logs") {
    Compress-Archive -Path "C:\CloudDeployment\Logs\*" -DestinationPath $destinationZip -Force
    Write-Host "All deployment logs successfully archived to: $destinationZip" -ForegroundColor Green
    Get-Item $destinationZip | Select-Object Name, @{Name="Size (MB)"; Expression={[math]::Round($_.Length / 1MB, 2)}}, LastWriteTime | Format-Table -AutoSize
} else {
    Write-Warning "Path 'C:\CloudDeployment\Logs' was not found on this node."
}
```

**Phase 4: Fallback Log Collection**

The Copy-DiagnosticData command copies diagnostic logs directly from mounted virtual hard disks (VHDs) to a specified local directory (e.g. C:\\temp\\Aldologs). Part of the OperationsModule, this command facilitates deep log analysis when standard management endpoints are unavailable.

**Important Note:** Running this fallback procedure requires shutting down the Control Plane VM to safely access and read the log volume VHDs.

```
$OperationsModuleFolder =
"C:\AzureLocalDisconnectedOperations\OperationsModule"
gci "$OperationsModuleFolder" -Recurse | Unblock-File
Import-module
$OperationsModuleFolder\ApplianceFallbackLogging.psm1
Import-Module
$OperationsModuleFolder\Azure.Local.DisconnectedOperations.Common.psm1 -Force
Import-Module $OperationsModuleFolder\LogCollectionModule.psm1
-Force
$recoverykeySet = (Get-
ApplianceBitlockerRecoveryKeys).recoverykeySet
$recoverykeySet | ConvertTo-JSON > c:\recoveryKey.json
#Step 1: Copy Diagnostic Data
# Create folder to store the output diagnostics data, we
created C:\temp\Aldologs
# FromDate & ToDate will depend on the duration of log to be
captured
Copy-DiagnosticData -DiagnosticLogPath "C:\temp\Aldologs" -
FromDate "2026-10-01T00:00:00.0000000Z" -ToDate "2026-10-
01T23:59:59.9999999Z" -RecoveryKeySet $recoverykeySet
```

**Remediation Steps**

This next section records the exact procedure for extracting the Resource Provider identity client certificate from the deployment VHDs, updating the cluster status via the local REST API script, and verifying runtime status.

**Phase 1: Extracting the Certificate from VHDs (GetCert.ps1)**

When managing disconnected deployments where direct access requires unlocking the appliance storage, the helper script mounts the VHDs of the control plane VM (IRVM01), unlocks BitLocker using the recovery keys, and extracts the client certificate to C:\\.

**Initialisation & Invocation:** Imports the Disconnected Operations, operations module, queries the appliance BitLocker recovery keys, and calls the extraction script:

```
Obtain the script from Microsoft Support.
```

**Underlying Extraction Script (GetCert.ps1):** Safely stops IRVM01, mounts its VHD stack (OSAndDocker_A, ArcA_ABData, and ArcA_SharedData_A), unlocks them via BitLocker recovery passwords, copies the client certificate (clm_ASZRP-RP_Identity_ClientCert.pfx) to C:\\, and restarts the VM:

```
Obtain the script from Microsoft Support.
```

**Phase 2: Completing Deployment Status (UpdateDeploymentStatus.ps1)**

Once the client certificate (clm_ASZRP-RP_Identity_ClientCert.pfx) is extracted to C:\\, authenticate against the local ARM endpoint using mutual certificate assertion to mark the deployment state as successful.

```
Obtain the script from Microsoft Support.
```

**Phase 3: Validation (get-vm)**

Verify that the local control plane and virtual machines are running normally following the update sequence. Running get-vm confirms the control plane and appliance VMs report a healthy status.

once validation (get-vm) confirms that the control plane and virtual machines (IRVM01 and control plane components) are running normally with a healthy status, the deployment process moves to finalisation and system integration:

- **Completion of Deployment Orchestration:** The local management engine recognises that the resource status has been successfully updated (DeploymentSuccess and reported properties set to Success), allowing the orchestrator to mark the entire deployment workflow as completed.
- **Arc Integration & Management:** With the control plane fully operational and registered, the local Azure Arc agents and resource providers resume normal operations, enabling management of the cluster either locally or via connected tooling.
- **Workload Readiness:** The infrastructure is now fully unblocked and ready for resource provisioning, storage configuration (such as Storage Spaces Direct volumes), and hosting production virtual machines or Kubernetes clusters.
