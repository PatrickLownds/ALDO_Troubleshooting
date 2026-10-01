# Addressing iLO vNIC Failover Cluster Exclusion and SBE 2608 DNS Resolution Failures

When deploying a multi-node cluster (such as Azure Local) on HPE Gen11 (configured in High Security mode) or Gen12 systems, a Virtual NIC (vNIC) is typically enabled by default to facilitate internal host-to-iLO communication. In Windows, this network interface presents itself as a **UsbNcm Host Device**.

Because this is a dedicated, internal host-to-BMC channel rather than a physical cluster network, this vNIC remains enabled for out-of-band management; however, it is critical to use the Failover Cluster registry settings (Add-ClusterExcludedAdapter) to explicitly exclude the adapter from cluster communications prior to running cluster creation (New-Cluster) or Arc deployment. Failing to exclude it can cause cluster validation failures, improper network binding, or deployment errors across Azure Local. This requirement also impacts other OEMs and their BMC adapters.

However, we have also observed a separate validation issue with the Solution Builder Extension (SBE 2608) when iLO 7 (and potentially iLO 6) in High Security mode is configured with DNS entries that fall outside the internal DNS namespace used during deployment.

By default, if iLO 7 is configured without static DNS or relies on DHCP for DNS assignment, it does not pass those DNS server addresses down to the OS Virtual NIC (UsbNcm Host Device). Conversely, if DNS is manually configured in iLO, those DNS values are inherited directly by the OS Virtual NIC.

During the SBE validation process, the deployment engine does not discriminate between the DNS entries configured on the UsbNcm Host Device versus the physical compute/management NICs; as a result, validation attempts to query DNS resolution across every active interface, leading to failure.

Because the UsbNcm Host Device (iLO vNIC) inherited in this case unreachable external DNS addresses from the iLO configuration, due to hardcoded static DNS entries, the validation engine attempted to query them during validation tests. Specifically, it tried to resolve the internal Active Directory domain namespace used for the deployment alongside standard external endpoints built into the validation routine (such as microsoft.com), causing the overall validation checks to fail.