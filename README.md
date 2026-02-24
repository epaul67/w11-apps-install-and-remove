Windows 11 Application Provisioning Script

Automated application provisioning for fresh Windows 11 installations using WinGet.

This script installs a curated base set of applications commonly required for enterprise workstations, including development tools, remote access utilities, productivity software, and supporting components.

Designed for repeatable laptop preparation and standardized workstation setup.

Overview

The script:

Uses native WinGet (App Installer)

Provides interactive install selection

Allows optional uninstall of existing applications

Handles MSIX/Appx removal when required

Automatically repairs WinGet sources if errors occur

Executes winget upgrade --all after installation

Continues execution even if individual installs fail

Provides a summary of failures at completion

Typical Use Cases

New employee laptop preparation

Standardized Windows 11 baseline deployment

Developer workstation setup

Rebuild after OS reinstallation

IT internal provisioning workflow

Requirements

Windows 11

WinGet (Microsoft App Installer installed)

PowerShell 5.1 or later

Local Administrator privileges (recommended)

Verify WinGet availability:

winget --version

If not available, install App Installer from Microsoft Store.

Execution
Recommended Method

Run the provided wrapper:

run-install.cmd

This automatically bypasses PowerShell execution restrictions for the session.

Manual Execution
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install-tools.ps1
Application Catalog

The application list is defined inside:

install-tools.ps1

Example:

$Apps = @(
    [pscustomobject]@{ Name="Google Chrome"; Id="Google.Chrome"; Scope="machine" },
    [pscustomobject]@{ Name="Microsoft Visual Studio Code"; Id="Microsoft.VisualStudioCode"; Scope="" },
    [pscustomobject]@{ Name="Git"; Id="Git.Git"; Scope="" }
)

To find additional packages:

winget search <application>
WinGet Error Handling

If WinGet fails (e.g., msstore certificate issues), the script automatically performs:

winget source remove msstore
winget source reset --force
winget source remove msstore
winget source update

The operation is then retried once.

The script forces installation from the winget source to avoid Store-related certificate or policy issues.

Upgrade Phase

After selected applications are installed, the script runs:

winget upgrade --all

This ensures all packages are updated to their latest available versions.

Logging and Failure Handling

Install and uninstall operations return success/failure status

Script execution continues even if individual packages fail

A summary is printed at the end listing:

Failed uninstalls

Failed installs

This behavior makes it suitable for batch provisioning scenarios.

Disk Usage Considerations

Large installations such as Docker Desktop, WSL, or Windows Updates may temporarily consume significant disk space.

Recommended cleanup if required:

cleanmgr

or

Dism.exe /Online /Cleanup-Image /StartComponentCleanup
