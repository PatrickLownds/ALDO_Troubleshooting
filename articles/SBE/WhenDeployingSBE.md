# Addressing iLO vNIC Failover Cluster Exclusion and SBE 2608 DNS Resolution Failures

When deploying a multi-node cluster (such as Azure Local) on HPE Gen11 (configured in High Security mode) or Gen12 systems, a Virtual NIC (vNIC) is typically enabled by default to facilitate internal host-to-iLO communication. In Windows, this network interface presents itself as a **UsbNcm Host Device**.

Because this is a dedicated, internal host-to-BMC channel rather than a physical cluster network, this vNIC remains enabled for out-of-band management; however, it is critical to use the Failover Cluster registry settings (Add-ClusterExcludedAdapter) to explicitly exclude the adapter from cluster communications before running cluster creation (New-Cluster) or Arc deployment. 

#### Figure 1: Verification of Excluded iLO UsbNcm Host Device Adapter
![Get-ClusterExcludedAdapter Output](https://raw.githubusercontent.com/PatrickLownds/ALDO_Troubleshooting/main/articles/SBE/vNIC.png)

Failing to exclude it can cause cluster validation failures, improper network binding, or deployment errors across Azure Local. This requirement also impacts other OEMs and their BMC adapters.

```powershell
# =========================================================================
# EXCLUDE iLO vNIC / UsbNcm Host Device FROM CLUSTER NETWORKING
# Must be executed before New-Cluster / Arc Deployment runs
# =========================================================================
Write-Host "Configuring Failover Cluster registry exclusion for iLO UsbNcm adapter..." -ForegroundColor Green

# Ensure the ClusSvc Parameters key exists
New-Item -Path 'HKLM:\System\CurrentControlSet\Services\ClusSvc' -Name 'Parameters' -Force | Out-Null

# Import NetAdapter module safely
Import-Module NetAdapter -DisableNameChecking

# Query and exclude the iLO vNIC interface description
$nicDescription = (Get-NetAdapter | Where-Object { 
    $_.InterfaceDescription -like "*UsbNcm Host Device*" -or 
    $_.InterfaceDescription -like "*USB-EEM*" 
}).InterfaceDescription

if ($nicDescription) {
    Add-ClusterExcludedAdapter -ExclusionType Description -ExclusionValue $nicDescription
    Write-Host "Successfully excluded adapter: $nicDescription" -ForegroundColor Green
} else {
    Write-Warning "UsbNcm Host Device adapter was not detected on this node."
}
# =========================================================================

# Verification Step: Confirm Failover Cluster adapter exclusion list
# Query registry entries under HKLM:\System\CurrentControlSet\Services\ClusSvc\Parameters
# to verify that network adapters matching 'UsbNcm Host Device' are ignored by cluster networking.
Get-ClusterExcludedAdapter -ExclusionType Description
```

However, we have also observed a separate validation issue with the Solution Builder Extension (SBE 2608) when iLO 7 (and potentially iLO 6) in High Security mode is configured with DNS entries that fall outside the internal DNS namespace used during deployment.

By default, if iLO 7 is configured without static DNS or relies on DHCP for DNS assignment, it does not pass those DNS server addresses down to the OS Virtual NIC (UsbNcm Host Device). Conversely, if DNS is manually configured in iLO, those DNS values are inherited directly by the OS Virtual NIC.

During the SBE validation process, the deployment engine does not discriminate between the DNS entries configured on the UsbNcm Host Device versus the physical compute/management NICs; as a result, validation attempts to query DNS resolution across every active interface, leading to failure.

#### Figure 2: SBE Validation Error
![iLO DNS Resolution Architecture](https://raw.githubusercontent.com/PatrickLownds/ALDO_Troubleshooting/main/articles/SBE/DNS.png)

Because the UsbNcm Host Device (iLO vNIC) inherited in this case unreachable external DNS addresses from the iLO configuration, due to hardcoded static DNS entries, the validation engine attempted to query them during validation tests. Specifically, it tried to resolve the internal Active Directory domain namespace used for the deployment alongside standard external endpoints built into the validation routine (such as microsoft.com), causing the overall validation checks to fail.
