# Azure Local Disconnected Operations (ALDO) Troubleshooting Portal

![Page Views](https://hits.dwyl.com/PatrickLownds/ALDO_Troubleshooting.svg)

Welcome to the diagnostics and troubleshooting repository for Azure Local Disconnected Operations. This project contains point-in-time reference guides, commands, and scripts compiled during engineering sessions.

## Available Documentation

* [**ALDO Diagnostics & Troubleshooting Guide**](./index.md) — Full technical breakdown of environment discovery, manifest inspection, log collections, Microsoft PG engineering checks, and kernel network packet tracing.
* [**Certificate Generation Delays in ALDO Build 2605**](./TroubleshootingCertificateGenerationALDOBuild2605.md) — Specific walkthrough for fixing infrastructure certificate generation blocks.
* [**Managing Secret and Certificate Rotation in Azure Local Disconnected Operations**](./articles/CertificateRotation/Managing%20Secret%20and%20Certificate%20Rotation%20in%20Azure%20Local%20Disconnected%20Operations.md) — Comprehensive guide covering lifecycle rotation triggers (post-deployment, scheduled renewals, compliance audits, and emergency compromise) along with operational procedures.

## Automation & Utility Scripts

* [**ALDO_Get-ExpiringCerts.ps1**](./articles/CertificateRotation/ALDO_Get-ExpiringCerts.ps1) — Automated PowerShell monitoring script using PSPKI auto-discovery to query AD CS and export expiring certificates to CSV.
* [**ALDO_Get-ActiveCerts.ps1**](./articles/CertificateRotation/ALDO_Get-ActiveCerts.ps1) — Interactive utility script with automated module dependencies for live AD CS certificate inspection.
---

*Maintained by [Patrick Lownds](https://github.com/PatrickLownds) • [Contact via Email](mailto:patrick.lownds@hpe.com)*
