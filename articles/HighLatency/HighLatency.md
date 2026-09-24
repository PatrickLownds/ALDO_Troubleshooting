# High Latency / Timeout in Connect-AzAccount Due to Default Instance Discovery in Disconnected Environments

## 1\. Issue Summary

During authentication in air-gapped / disconnected Azure Local environments, Connect-AzAccount (via Az.Accounts / MSAL) experiences significant execution delays and timeouts. MSAL attempts to connect to the public instance discovery endpoint (<https://login.microsoftonline.com/common/discovery/instance>)) prior to falling back or completing authentication against private local endpoints.

## 2\. Environment & Scope

- **Observed Behaviour:** When running Connect-AzAccount in an isolated environment without public internet access, the authentication request hangs for extended periods due to repeated retries against public Microsoft discovery endpoints.
- **Root Cause Analysis:** MSAL defaults to querying \[<https://login.microsoftonline.com/common/discovery/instance\>](<https://login.microsoftonline.com/common/discovery/instance>) for tenant/environment metadata validation. In private network configurations, these outbound public HTTP requests timeout before the session falls back to private control plane and ARM endpoints.
- **Log Findings:** Telemetry confirms that private authentication and ARM endpoints are fully reachable and functioning as expected. The latency stems strictly from un-suppressed public instance discovery in Az.Accounts.

## 4\. Impact

- **Operational Friction:** Operators and automated routines experience severe timeouts and delays on every invocation of Connect-AzAccount.
- **Deployment Blocker:** High latency degrades deployment automation and operator workflows during disconnected cluster setups.

## 5\. Proposed Workaround & Mitigations

- **Parameter Usage:** Validate if passing -DisableInstanceDiscovery directly to Connect-AzAccount bypasses the public endpoint lookup:

```powershell
Connect-AzAccount -EnvironmentName "Azure.Local" -DisableInstanceDiscovery $true
```

**Environment Configuration:** Confirm if setting environment-wide discovery suppression or pre-configuring local authority metadata prevents the timeout loop across all script contexts.
