**Running Software Defined Networking Enabled by Azure Arc on Azure Local Disconnected Operations**

Software Defined Networking (SDN) provides a centralised approach to configuring and managing datacenter networks and network services, including switching, routing, and load balancing. By leveraging SDN, organisations can dynamically create, secure, and connect their infrastructure to align with evolving application requirements.

When deploying **Azure Local in disconnected operations**, the primary focus for modern deployments is Software Defined Networking enabled by Azure Arc, rather than traditional on-premises SDN. Managing SDN via Azure Arc ensures seamless integration with cloud-native management paradigms, robust network security, and predictable traffic flows. This guide details the Arc-enabled SDN approach, highlights operational considerations, compares it with traditional SDN, and outlines supported host networking patterns.

**1\. SDN Management Approaches on Azure Local**

While Azure Local supports two SDN management pathways, deployments targeting modern hybrid and disconnected scenarios focus on SDN enabled by Azure Arc. Traditional on-premises SDN remains available primarily for legacy environments.

**Option A: SDN Enabled by Azure Arc**

- **Availability:** Available from Azure Local version 2506 (OS version 26100.xxxx or later).
- **Architecture:** The Network Controller runs as a **Failover Cluster service** rather than inside a traditional virtual machine (VM). It integrates directly with the Azure Arc control plane.
- **Management Tooling:** Azure portal, Azure CLI, and Azure Resource Manager (ARM) templates.
- **Security:** Allows you to create and apply Network Security Groups (NSGs) directly to logical networks and Azure Local VM network interfaces (NICs).

**Important Note for AKS:** Azure Kubernetes Service (AKS) is supported on Azure Local instances configured with SDN enabled by Arc. However, associating NSGs with the logical network used for AKS workload deployments or directly with AKS workload VM NICs is **not supported**.

**Option B: SDN Managed by On-Premises Tools**

- **Availability:** Supported for Windows Server and Azure Local version 2311.2 or later.
- **Architecture:** Utilises traditional on-premises components. You choose which components to deploy from three main options: **Network Controller**, **Software Load Balancer (SLB)**, and **Gateway**.
- **Management Tooling:** Windows Admin Center, SDN Express scripts, PowerShell, and System Center Virtual Machine Manager (SCVMM).
- **Security:** NSG management is restricted to unmanaged VMs deployed via local tools (e.g., Windows Admin Center, Hyper-V Manager, SCVMM, and Failover Cluster Manager).

**2\. Important Operational Considerations**

To prevent asymmetric networking, packet loss, and configuration corruption, adhere strictly to these operational boundaries:

- **Consistency is Mandatory:** Never mix management methods. If SDN was enabled using PowerShell (Add-EceFeature), **do not** attempt to manage it with on-premises tools like Windows Admin Center or SDN Express scripts. Conversely, if Network Controller was deployed via on-premises tools, **do not** run the Arc-enabled PowerShell enablement scripts.
- **VM Scope Boundaries:**
  - Arc-Enabled SDN: In-scope VMs are strictly Azure Local VMs deployed via Azure client interfaces (Azure CLI, Azure portal, ARM templates). Do not combine these VMs with on-premises managed NSGs.
  - On-Premises SDN: In-scope VMs are strictly unmanaged VMs deployed via local tools (Hyper-V Manager, SCVMM, etc.).
- **Static NIC Best Practice:** If you provision multiple static NICs on an Azure Local VM under Arc-enabled SDN, **remove the default gateway from all secondary NICs**. Leaving default gateways on secondary NICs leads to asymmetric routing and packet drops.

**3\. Comparison Summary: Arc-Enabled vs. On-Premises SDN**

| Feature / Dimension     | SDN Enabled by Azure Arc                          | SDN Managed by On-Premises Tools                                                                                |
| ----------------------- | ------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Supported SDN Resources | • Logical networks<br><br>• VM NICs<br><br>• NSGs | • Logical networks<br><br>• VM NICs<br><br>• NSGs<br><br>• Virtual networks<br><br>• SLBs<br><br>• VPN Gateways |
| Supported VMs           | Azure Local VMs                                   | • Hyper-V VMs<br>• SCVMM VMs                                                                                    |
| Management Tools        | Azure portal, Azure CLI, ARM templates            | SDN Express scripts, Windows Admin Center, PowerShell, SCVMM                                                    |

**4\. Unsupported Scenarios for SDN Enabled by Arc**

When deploying SDN enabled by Arc on Azure Local, note that certain traditional SDN features and configurations are explicitly unsupported:

- **Unsupported SDN Resources:** Virtual networks (overlay networks), Software Load Balancers (SLB), and Gateways (VPN, Layer 3, GRE) are currently not supported in the Arc-enabled SDN model.
- **Hybrid Tooling:** Mixing Azure management (Portal, CLI, ARM) with local tools (Windows Admin Center, SDN Express scripts) breaks consistency and is unsupported.
- **Multi-Cast Workloads:** Multi-cast workloads are unsupported because Arc-enabled SDN currently facilitates **unicast communication exclusively**.

**5\. Supported Host Networking Patterns**

Before deploying Azure Local and enabling SDN, ensure your host networking design maps to one of the following validated patterns:

1. **Group All Traffic on a Single Network Intent**
   - Suitable for single-node or multi-node configurations using **switched storage network connectivity**.
   - Exposes a single virtual switch to create SDN resources. Azure Virtual Filtering extensions automatically turn on once the Network Controller is enabled.
2. **Group Management and Compute Traffic in One Intent with a Separate Storage Intent**
   - Supported on single-node or multi-node configurations (grouping management and compute with _no_ storage intent is restricted to single-node clusters).
   - Requires **switched storage connectivity** across all node sizes under disconnected operations.
3. **Custom Configuration for Disaggregated Host Networks**
   - Utilises up to three discrete network intents (Management intent, Compute intent, Storage intent) provided sufficient network adapter ports exist.
   - Requires **switched storage connectivity** across all node sizes under disconnected operations.
4. **Automating Arc-Enabled SDN and NSGs on Azure Local Disconnected Operations**

When running Azure Local in air-gapped or disconnected operations, configuring Software Defined Networking (SDN) and managing Network Security Groups (NSGs) requires targeting the local private control plane endpoint (autonomous.cloud.private). Because current ALDO/SDN builds implement a hybrid control model, where host features and logical networks are managed via PowerShell, while NSGs are handled via the Azure CLI extension, automating the deployment requires a multi-step sequence.

The complete automation script below provisions the network controller host extension, authenticates against the local disconnected control plane, creates a logical network, provisions an NSG with custom RDP inbound filtering rules, and attaches it to the network.

```
<#
================================================================================
SCRIPT NAME : Deploy-ALDONetworkingAndNSG.ps1
DESCRIPTION : End-to-end automation for provisioning Software Defined Networking
              (SDN Network Controller), Arc VM Logical Networks, and Network
              Security Groups (NSGs) in an Azure Local Disconnected
              Operations (ALDO) environment.
================================================================================
PREREQUISITES & ENVIRONMENT:
--------------------------------------------------------------------------------
1. Targeted Environment:
   - Azure Local Disconnected Operations (ALDO) standalone/disconnected cluster.
   - Requires access to physical cluster nodes (for host SDN features) and
     the local ARM control plane endpoint (autonomous.cloud.private).
2. Module & Tool Dependencies:
   - Az.StackHCIVM PowerShell Module (Local version supporting New-AzStackHCIVMLogicalNetwork).
   - Azure CLI with the `stack-hci-vm` extension installed.
3. Authentication & Elevation Requirements:
   - Elevated Administrator privileges on the physical cluster node (for Add-EceFeature).
   - Local Service Principal or Device Code credentials for local ARM plane auth.
OPERATIONAL NOTES & ARCHITECTURE:
--------------------------------------------------------------------------------
- Host-Level SDN Requirements:
  The SDN prefix parameter ($SDNPrefix) passed to Add-EceFeature MUST be
  8 characters or fewer due to NetBIOS/DNS naming constraints on cluster nodes.
- Dual Control Planes:
  Because the local `Az.StackHCIVM` PowerShell module in current ALDO builds
  lacks native NSG management cmdlets, this script utilises a hybrid approach:
    1. Native PowerShell (`Az.StackHCIVM`) for Arc Logical Network creation.
    2. Azure CLI (`az stack-hci-vm`) for NSG creation, rule definition, and binding.
- Interactive Execution Point:
  The script pauses at the `az login --use-device-code` step to allow device code
  authentication against the local disconnected ARM endpoint.
#>
# Execute in an Elevated PowerShell session on a Cluster Node
$SDNPrefix = "azssgp"
Add-EceFeature -Name NC `
    -SDNPrefix $SDNPrefix `
    -AcknowledgeMaintenanceWindow `
    -AcknowledgeDNSRecordCreation
# Authenticate against ALDO Local Endpoint (Disable Instance Discovery to prevent timeouts)
$applianceCloudName = "azure.local"
$applianceFQDN = "autonomous.cloud.private"
Connect-AzAccount -EnvironmentName $applianceCloudName -UseDeviceAuthentication
# Install a dependancy module
Install-Module Az.StackHCIVM
# Variables
$ResourceGroupName = "aldorg"
$Location          = "autonomous"
$CustomLocationId  = "/subscriptions/f71dbedc-b817-a08c-3013-86637e579238/resourcegroups/azurelocal-workload-cluster/providers/microsoft.extendedlocation/customlocations/aldo-wlc-customlocation"
$LNetName          = "lnet-workload-nsg"
$VlanId            = 1211
$AddressPrefix     = "172.12.11.0/24"
$Gateway           = "172.12.11.253"
$DnsServer         = "172.12.11.12"
$IpPoolStart       = "172.12.11.140"
$IpPoolEnd         = "172.12.11.149"
$NsgName           = "nsg-workload-allow-rdp"
$MgmtSubnetCidr    = "172.12.11.0/24"
$NicName           = "nic-vm01-eth0"
$IpAllocationMethod = "Static"
$VmSwitchName       = "ConvergedSwitch(managementcomputestorage)"   # Replace with your actual virtual switch name on the nodes
# Create Logical Network using direct parameters
New-AzStackHCIVMLogicalNetwork `
    -Name $LNetName `
    -ResourceGroupName $ResourceGroupName `
    -Location $Location `
    -CustomLocationId /subscriptions/f71dbedc-b817-a08c-3013-86637e579238/resourcegroups/azurelocal-workload-cluster/providers/microsoft.extendedlocation/customlocations/aldo-wlc-customlocation `
    -Vlan $VlanId `
    -AddressPrefix $AddressPrefix `
    -IpAllocationMethod $IpAllocationMethod `
    -IpPoolStart $IpPoolStart `
    -IpPoolEnd $IpPoolEnd `
    -DnsServer $DnsServer `
    -VmSwitchName $VmSwitchName
# ------------------------------------------------------------------------------
# PIVOT TO AZURE CLI:
# The local Az.StackHCIVM PowerShell module in this ALDO release lacks compiled
# cmdlets for Network Security Groups (NSGs) and Security Rules.
# We switch to the 'az stack-hci-vm' CLI extension, which interacts directly
# with the local Microsoft.AzureStackHCI/networkSecurityGroups ARM REST provider.
# ------------------------------------------------------------------------------
az login --use-device-code
# Set variables from your environment
$ResourceGroupName = "aldorg"
$Location          = "autonomous"
$CustomLocationId  = "/subscriptions/f71dbedc-b817-a08c-3013-86637e579238/resourcegroups/azurelocal-workload-cluster/providers/microsoft.extendedlocation/customlocations/aldo-wlc-customlocation"
$NsgName           = "nsg-workload-allow-rdp"
$MgmtSubnetCidr    = "172.12.11.0/24"
$LNetName          = "lnet-workload-nsg"
$NicName           = "nic-vm01-eth0"
# 1. Create the NSG Resource
az stack-hci-vm network nsg create `
  --resource-group $ResourceGroupName `
  --name $NsgName `
  --location $Location `
  --custom-location $CustomLocationId
# 2. Add Rule: Allow RDP (Port 3389) from Management Subnet
az stack-hci-vm network nsg rule create `
  --resource-group $ResourceGroupName `
  --nsg-name $NsgName `
  --name "Allow-RDP-From-Mgmt" `
  --priority 100 `
  --direction Inbound `
  --access Allow `
  --protocol Tcp `
  --source-address-prefix $MgmtSubnetCidr `
  --source-port-range "*" `
  --destination-address-prefix "*" `
  --destination-port-range 3389 `
  --custom-location $CustomLocationId
# 3. Add Rule: Deny All Other Inbound Traffic
az stack-hci-vm network nsg rule create `
  --resource-group $ResourceGroupName `
  --nsg-name $NsgName `
  --name "Deny-All-Inbound" `
  --priority 4096 `
  --direction Inbound `
  --access Deny `
  --protocol "*" `
  --source-address-prefix "*" `
  --source-port-range "*" `
  --destination-address-prefix "*" `
  --destination-port-range "*" `
  --custom-location $CustomLocationId
# Query NSG Resource ID
$NsgResourceId = (az stack-hci-vm network nsg show --resource-group $ResourceGroupName --name $NsgName --query id -o tsv)
# Display all rules created inside your NSG
az stack-hci-vm network nsg rule list `
  --resource-group $ResourceGroupName `
  --nsg-name $NsgName `
  --output table
# Option A: Attach NSG to Logical Network
az stack-hci-vm network lnet update `
  --resource-group $ResourceGroupName `
  --name $LNetName `
  --nsg $NsgResourceId
# List All Rules in the NSG
az stack-hci-vm network nsg rule list `
  --resource-group $ResourceGroupName `
  --nsg-name $NsgName `
  --output table
# View Full Logical Network Configuration
az stack-hci-vm network lnet show `
  --resource-group $ResourceGroupName `
  --name $LNetName `
  --output json
# List All Logical Networks and Their Attached NSGs in a Resource Group
az stack-hci-vm network lnet list `
  --resource-group $ResourceGroupName `
  --query "[].{LogicalNetwork:name, AttachedNSG:networkSecurityGroup.id}" `
  --output table
# Option B: Attach NSG to VM Network Interface
# az stack-hci-vm network nic update `
#   --resource-group $ResourceGroupName `
#   --name $NicName `
#   --nsg $NsgResourceId
# End
```