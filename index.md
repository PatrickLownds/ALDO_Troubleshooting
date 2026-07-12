---
layout: default
title: "Azure Local Disconnected Operations: Diagnostics & Troubleshooting Guide"
description: ""
---

Here is the structured breakdown of all the commands and script paths extracted from a recent troubleshooting session for Azure Local Disconnected Operations (ALDO). These commands were used to **identify the cluster identity**, **import the specialised disconnected operations modules**, **verify local REST API system readiness**, **audit security certificates**, **track kernel packet drops**, **trigger localised appliance log collection**, stage them, ship them to Microsoft via a device code login, and investigate a specific BitLocker volume key protector failure.

**Operational Note:** Keeping this record as a point-in-time reference is highly valuable, especially given the level of technical detail captured during live engineering sessions. **At the same time, it is equally important to stay continuously aligned with the latest public documentation for any updates. The official framework evolves rapidly, and referencing the live documents ensures any subtle architectural changes or updated prerequisites are not overlooked.**

## Environment Discovery & Manifest Inspection

Here is the structured breakdown of all the commands and script paths extracted from your troubleshooting session for **Azure Local Disconnected Operations.**

These commands were used to identify the cluster identity, import the specialised disconnected operations modules, trigger localised appliance log collection, stage them, ship them to Microsoft via a device code login, and investigate a specific BitLocker volume key protector failure.

cat C:\\Users\\Administrator\\AppData\\Local\\AzureLocalOpModuleDev\\Manifest.json

cat "D:\\AzureLocalDisconnectedOperations\\AzureLocal.disconnectedoperations.manifest.json"

**Purpose:** Inspects the JSON files containing the registration properties of the disconnected environment. It exposes critical routing parameters like the subscriptionId, resourceGroupName, stampId, and explicitly confirms the connectionIntent is set to "Disconnected".

\$StampId =(Get-ApplianceInstanceConfiguration).StampId 4>\$null

\$StampId

**Purpose:** Querying the local appliance orchestration layer to extract the unique physical footprint identifier (StampId) of the deployment. The 4>\$null parameter suppresses the verbose/informational stream output to ensure only the clean string variable is captured.

Invoke-RestMethod -Uri "<https://localhost:8081/api/v1/systemreadiness>" -Method Get -SkipCertificateCheck

**Purpose:** Hits the local offline orchestration agent's API gateway directly. It evaluates full-stack system readiness metrics (such as active provisioning phases, environment dependencies, and validation states). The -SkipCertificateCheck switch is mandatory here because, during an identity or deployment failure, local self-signed internal API communication tokens might not have a trusted root anchor established yet.

## Module Importation & Validation

Because this is a disconnected environment, the native Azure Arc automated control plane tracking is unavailable. The engineering team manually loaded local fallback and operations modules to unlock diagnostic capabilities.

\# Sourced from original: #gci "\$OperationsModuleFolder" -Recurse | Unblock-File

Get-ChildItem -Path "C:\\AzureLocal\\OperationsModule\\" -Recurse | Unblock-File

**Purpose:** Strips the web-download/external-origin metadata flag (Zone.Identifier) from the copied modules. This prevents execution policy blocks when running custom administrative scripts or modules in an isolated cluster environment.

Import-module C:\\AzureLocal\\OperationsModule\\ApplianceFallbackLogging.psm1

Import-Module C:\\AzureLocal\\OperationsModule\\Azure.Local.DisconnectedOperations.Common.psm1 -Force

Import-Module C:\\AzureLocal\\OperationsModule\\LogCollectionModule.psm1 -Force

**Purpose:** Manually forces (-Force) the loading of localized PowerShell modules responsible for managing the isolated appliance operations framework, standard fallback exception logging, and the diagnostic collection engines.

get-command Invoke-AzureLocalDisconnectedLogCollection

get-command Send-DiagnosticData

**Purpose:** A validation check used to confirm that the manually imported modules successfully registered the necessary cmdlets within the active PowerShell session before execution.

## Log Collection, Retrieval & Historical Tracking

These commands are used to review past tasks and run the aggressive, full-stack log gatherers that compile system diagnostic logs across the host nodes.

Get-ApplianceLogCollectionHistory

Get-ApplianceLogCollectionJobStatus

**Purpose:** Queries the internal appliance log database to review the success/failure history of past diagnostic dumps and track the progress of currently executing background gathering jobs.

\$LogSharepath = "\\\\XXX"

\$fromDate = ((Get-Date).AddHours(-30))

\$toDate = (Get-Date)

\$operationId = Invoke-ApplianceLogCollectionAndSaveToShareFolder -FromDate \$fromDate -ToDate \$toDate \`

\-LogOutputShareFolderPath \$LogSharepath -ShareFolderUsername "XX" -ShareFolderPassword (ConvertTo-SecureString "XX" -AsPlainText -Force)

**Purpose:** Triggers a targeted localised log collection capturing events across a specific time boundary (the previous 30 hours). It aggregates cluster logs, appliance states, and hypervisor records, compresses them, and dumps them onto an external network share folder using secured credentials.

## Transferring Diagnostics to Microsoft

Once the logs are locally generated, they must be transmitted securely to the Microsoft Product Group (PG) through an authenticated out-of-band pathway using an Azure identity framework.

Send-DiagnosticData \`

\-ResourceGroupName "Resource group" \`

\-SubscriptionId "Subscription ID" \`

\-TenantId "Tenant ID" \`

\-RegistrationWithDeviceCode \`

\-RegistrationRegion "eastus2" \`

\-DiagnosticLogPath "C:\\Temp\\ALDOLogs\\"

**Purpose:** The core tool used to upload the compiled diagnostic logs out of the local environment (C:\\Temp\\ALDOLogs\\) directly to Microsoft's secure back-end cloud repository. Crucially, the -RegistrationWithDeviceCode flag invokes an interactive device login prompt, allowing authentication to occur from another machine that has live internet connectivity.

## Specific Product Group (PG) Engineering Checks

During your session, the deployment upgrade hit roadblocks related to Identity and BitLocker. The Microsoft Product Group requested a specific query on the seed node to diagnose why the orchestration engine was stalling.

Get-BitLockerVolume | Where-Object {

((\$\_.KeyProtector | Where-Object KeyProtectorType -eq 'RecoveryPassword').Count) -gt 1

} | Select-Object MountPoint

**Purpose:** This script audits all encrypted disk volumes on the node, counting how many RecoveryPassword key protectors exist per disk.

**The Underlying Bug Reason:** The PG team suspected an identity or volume logic glitch where a drive might have mistakenly acquired _multiple_ active recovery passwords (which can break the automated validation loops during full-stack orchestration upgrades). Your execution yielded **"no results"**, allowing the PG team to rule out multiple key protectors as the active point of failure.

Invoke-Expression -Command "C:\\ProgramData\\Microsoft\\AzureLocalDisconnectedOperations\\Scripts\\CertScan.ps1"

**Purpose:** Runs a full infrastructure certificate validation sweep. Because the cluster upgrade hit explicit identity blocks, this script audits the health of internal cluster communication certificates, node identity tokens, and encryption boundaries. It explicitly parses out expired thumbprints, invalid certificate authority chains, or missing access rights on private keys that would completely break local domain communication and identity handshakes.

## Advanced Kernel Network Diagnostics

When standard ping tests pass but high-level infrastructure handshakes (such as Active Directory authentication or Kerberos ticket exchanges) continue to time out, kernel-level packet monitoring is required to see if the operating system is dropping packets internally.

\# Pre-stage the local temporary diagnostics directory container

New-Item -ItemType Directory -Path "C:\\Temp\\ALDOLogs\\" -Force

pktmon filter remove

pktmon filter add -p 53

pktmon filter add -p 389

pktmon start --capture --drop-only --file-name "C:\\Temp\\ALDOLogs\\PktMonDropTrace.etl"

\# ...reproduce identity error payload...

pktmon stop

pktmon filter remove

**Purpose:** Captures diagnostic packet traces directly inside the Windows networking stack components (such as the virtual switch layer). By applying filters for specific identity traffic (DNS port 53 / LDAP port 389) and utilising the --drop-only modifier, the tool filters out successful network noise and _only logs the exact packets that the operating system dropped_, instantly highlighting if an internal firewall rule or virtual switch configuration mismatch is killing your identity authentications.

### Additional Resources
* Learn how to fix [Certificate Generation Delays in ALDO Build 2605](TroubleshootingCertificateGenerationALDOBuild2605)
