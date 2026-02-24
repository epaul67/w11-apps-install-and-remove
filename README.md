# Windows 11 Application Provisioning Script

Automated application provisioning for fresh Windows 11 installations using WinGet.

This script installs a curated base set of applications commonly required for enterprise workstations, including development tools, remote access utilities, productivity software, and supporting components.

Designed for repeatable laptop preparation and standardized workstation setup.

---

## Overview

The script:

- Uses native **WinGet** (App Installer)
- Provides interactive install selection
- Allows optional uninstall of existing applications
- Handles MSIX/Appx removal when required
- Automatically repairs WinGet sources if errors occur
- Executes `winget upgrade --all` after installation
- Continues execution even if individual installs fail
- Provides a summary of failures at completion

---

## Typical Use Cases

- New employee laptop preparation
- Standardized Windows 11 baseline deployment
- Developer workstation setup
- Rebuild after OS reinstallation
- IT internal provisioning workflow

---

## Requirements

- Windows 11
- WinGet (Microsoft App Installer installed)
- PowerShell 5.1 or later
- Local Administrator privileges (recommended)

Verify WinGet availability:

```powershell
winget --version

If not available, install App Installer from Microsoft Store.
Execution
Recommended Method

Run: </>cmd

run-install.cmd

This automatically bypasses PowerShell execution restrictions for the session.

Manual Execution
</>PowerShell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install-tools.ps1
