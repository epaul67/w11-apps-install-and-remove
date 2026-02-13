# install-tools.ps1
# Interactive installer/uninstaller using winget only.
# - Lists ALL winget-detected installed apps for optional uninstall (with filter).
# - Then lets you choose apps from your catalog to install.
# - Auto repairs winget sources and retries once on errors.
# - CONTINUE ON ERROR + SUMMARY
# - After installs: winget upgrade --all
#
# Run (Admin PowerShell):
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\install-tools.ps1

$ErrorActionPreference = "Stop"

function Ensure-WinGet {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: winget not found. Install/repair 'App Installer' from Microsoft Store." -ForegroundColor Red
        exit 1
    }
}

function Repair-WinGetSources {
    Write-Host ""
    Write-Host "Winget error detected. Repairing sources..." -ForegroundColor Yellow

    try { winget source remove msstore | Out-Null } catch { }

    try { winget source reset --force | Out-Null } catch { }

    # Reset brings msstore back — remove it again
    try { winget source remove msstore | Out-Null } catch { }

    try { winget source update | Out-Null } catch { }

    Write-Host "Sources repaired (msstore removed)." -ForegroundColor Yellow
    Write-Host ""
}


function Invoke-WinGet {
    param(
        [Parameter(Mandatory = $true)][string[]]$Args,
        [Parameter(Mandatory = $true)][string]$ActionLabel
    )

    & winget @Args
    $code = $LASTEXITCODE

    if ($code -ne 0) {
        Write-Host "$ActionLabel failed (ExitCode=$code). Trying repair + retry..." -ForegroundColor Yellow
        Repair-WinGetSources

        & winget @Args
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            throw "$ActionLabel failed again (ExitCode=$code)."
        }
    }

    # Do NOT throw; return success/failure
    return ($code -eq 0)
}

function Install-App {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Scope = ""   # "machine" or ""
    )

    $args = @(
        "install",
        "--id", $Id,
        "--exact",
        "--source", "winget",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--silent"
    )
    if ($Scope -ne "") { $args += @("--scope", $Scope) }

    Write-Host "Installing: $Name ($Id)" -ForegroundColor Cyan
    $ok = Invoke-WinGet -Args $args -ActionLabel ("Install " + $Name)

    if ($ok) {
        Write-Host "OK: $Name" -ForegroundColor Green
    }
    else {
        Write-Host "FAILED: $Name" -ForegroundColor Red
    }
    Write-Host ""
    return $ok
}

function Uninstall-Package {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$Pkg
    )

    # MSIX/Appx uninstall path
    if (-not [string]::IsNullOrWhiteSpace($Pkg.Id) -and $Pkg.Id -like "MSIX\*") {
        $msix = $Pkg.Id.Substring(5)              # drop "MSIX\"
        $packageName = ($msix -split "\s+")[0]    # stop at whitespace if any

        Write-Host "Uninstalling MSIX/Appx: $($Pkg.Name) ($packageName)" -ForegroundColor Magenta

        try {
            # Remove for current user
            $found = Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue
            if ($found) {
                $found | Remove-AppxPackage -ErrorAction SilentlyContinue
            }
            else {
                Write-Host "Appx package not found for current user (may already be removed)." -ForegroundColor DarkGray
            }

            # Deprovision for new users (optional)
            $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $packageName }
            if ($prov) {
                Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue | Out-Null
                Write-Host "Deprovisioned for new users." -ForegroundColor DarkGray
            }

            Write-Host "OK: removed (MSIX/Appx) $($Pkg.Name)" -ForegroundColor Green
            Write-Host ""
            return $true
        }
        catch {
            Write-Host "FAILED: MSIX/Appx removal for $($Pkg.Name): $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
            return $false
        }
    }

    # Normal winget uninstall path
    if (-not [string]::IsNullOrWhiteSpace($Pkg.Id)) {
        $wgArgs = @("uninstall", "--id", $Pkg.Id, "--exact", "--accept-source-agreements", "--silent", "--source", "winget")
        Write-Host "Uninstalling: $($Pkg.Name) ($($Pkg.Id))" -ForegroundColor Magenta
        $ok = Invoke-WinGet -Args $wgArgs -ActionLabel ("Uninstall " + $Pkg.Name)
    }
    else {
        $wgArgs = @("uninstall", "--name", $Pkg.Name, "--exact", "--accept-source-agreements", "--silent", "--source", "winget")
        Write-Host "Uninstalling by name (no Id): $($Pkg.Name)" -ForegroundColor Magenta
        $ok = Invoke-WinGet -Args $wgArgs -ActionLabel ("Uninstall " + $Pkg.Name)
    }

    if ($ok) {
        Write-Host "OK: removed $($Pkg.Name)" -ForegroundColor Green
    }
    else {
        Write-Host "FAILED: $($Pkg.Name)" -ForegroundColor Red
    }
    Write-Host ""
    return $ok
}


function Show-Menu {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][object[]]$Items
    )

    Write-Host ""
    Write-Host $Title -ForegroundColor White
    Write-Host ("Total items: {0}" -f $Items.Count) -ForegroundColor DarkGray

    for ($i = 0; $i -lt $Items.Count; $i++) {
        $n = $i + 1
        Write-Host ("[{0,3}] {1}" -f $n, $Items[$i].Name)
    }

    Write-Host ""
    Write-Host "Type selection: e.g. 1,3,5 or 1-4 or all or q" -ForegroundColor DarkGray
}

function Parse-Selection {
    param(
        [string]$Selection,
        [Parameter(Mandatory = $true)][int]$Max
    )

    if ([string]::IsNullOrWhiteSpace($Selection)) { return @() }

    $Selection = $Selection.Trim().ToLower()
    if ($Selection -eq "q" -or $Selection -eq "quit" -or $Selection -eq "exit") { return @() }
    if ($Selection -eq "all") { return 1..$Max }

    $set = New-Object System.Collections.Generic.HashSet[int]

    foreach ($part in ($Selection -split ",")) {
        $p = $part.Trim()
        if ([string]::IsNullOrWhiteSpace($p)) { continue }

        # ASCII-only range support: 141-143
        if ($p -match "^(\d+)\s*-\s*(\d+)$") {
            $a = [int]$matches[1]
            $b = [int]$matches[2]
            if ($a -gt $b) { $tmp = $a; $a = $b; $b = $tmp }
            foreach ($k in $a..$b) { [void]$set.Add($k) }
        }
        elseif ($p -match "^\d+$") {
            [void]$set.Add([int]$p)
        }
    }

    $valid = @()
    foreach ($x in $set) {
        if ($x -ge 1 -and $x -le $Max) { $valid += $x }
    }

    return $valid | Sort-Object
}

function Get-WinGetInstalledPackages {
    # Try JSON output first. If not supported, parse text output.
    try {
        $json = & winget list --output json 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($json)) {
            $data = $json | ConvertFrom-Json
            $pkgs = @()
            foreach ($src in $data.Sources) {
                foreach ($p in $src.Packages) {
                    $pkgs += [pscustomobject]@{
                        Name    = $p.Name
                        Id      = $p.Id
                        Version = $p.Version
                        Source  = $src.Name
                    }
                }
            }
            return $pkgs
        }
    }
    catch { }

    # Fallback: parse plain 'winget list' output
    try {
        $lines = & winget list 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $lines) { return @() }

        $pkgs = @()
        $started = $false

        foreach ($line in $lines) {
            if (-not $started) {
                # Look for header line containing Name and Id
                if ($line -match "^\s*Name\s+Id\s+Version") { $started = $true }
                continue
            }

            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            if ($line -match "^\s*-{3,}\s*$") { continue }

            $cols = ($line -split "\s{2,}") | Where-Object { $_ -ne "" }

            $name = if ($cols.Count -ge 1) { $cols[0] } else { "" }
            $id = if ($cols.Count -ge 2) { $cols[1] } else { "" }
            $ver = if ($cols.Count -ge 3) { $cols[2] } else { "" }
            $src = if ($cols.Count -ge 5) { $cols[4] } else { "" }

            if (-not [string]::IsNullOrWhiteSpace($name)) {
                $pkgs += [pscustomobject]@{
                    Name    = $name
                    Id      = $id
                    Version = $ver
                    Source  = $src
                }
            }
        }

        return $pkgs
    }
    catch {
        return @()
    }
}

function Upgrade-All {
    Write-Host "Running: winget upgrade --all ..." -ForegroundColor White
    $args = @(
        "upgrade",
        "--all",
        "--source", "winget",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--silent"
    )
    $ok = Invoke-WinGet -Args $args -ActionLabel "Upgrade all"
    if ($ok) {
        Write-Host "OK: winget upgrade --all completed." -ForegroundColor Green
    }
    else {
        Write-Host "WARNING: winget upgrade --all failed." -ForegroundColor Yellow
    }
    Write-Host ""
    return $ok
}

# --- Your install catalog (edit/add apps here) ---
$Apps = @(
    [pscustomobject]@{ Name = "Google Chrome"; Id = "Google.Chrome"; Scope = "machine" },
    [pscustomobject]@{ Name = "Google Credential Provider"; Id = "Google.CredentialProviderForWindows"; Scope = "" },
    [pscustomobject]@{ Name = "Notepad++"; Id = "Notepad++.Notepad++"; Scope = "" },
    [pscustomobject]@{ Name = "Viscosity"; Id = "SparkLabs.Viscosity"; Scope = "" },
    [pscustomobject]@{ Name = "Visual Studio Code"; Id = "Microsoft.VisualStudioCode"; Scope = "" },
    [pscustomobject]@{ Name = "PuTTY"; Id = "PuTTY.PuTTY"; Scope = "" },
    [pscustomobject]@{ Name = "Git"; Id = "Git.Git"; Scope = "" },
    [pscustomobject]@{ Name = "Google Drive"; Id = "Google.GoogleDrive"; Scope = "" },
    [pscustomobject]@{ Name = "Citrix Workspace"; Id = "Citrix.Workspace"; Scope = "" },
    [pscustomobject]@{ Name = "Sourcetree"; Id = "Atlassian.Sourcetree"; Scope = "" },
    [pscustomobject]@{ Name = "WSL"; Id = "Microsoft.WSL"; Scope = "" },
    [pscustomobject]@{ Name = "Docker Desktop"; Id = "Docker.DockerDesktop"; Scope = "machine" }
)

# --- Main ---
Ensure-WinGet

$FailedUninstalls = New-Object System.Collections.Generic.List[string]
$FailedInstalls = New-Object System.Collections.Generic.List[string]

# 1) Optional uninstall of ALL winget-detected apps
$AllInstalled = Get-WinGetInstalledPackages | Sort-Object Name

if ($AllInstalled.Count -gt 0) {
    Write-Host ""
    Write-Host ("Installed apps (winget-detected): {0}" -f $AllInstalled.Count) -ForegroundColor White
    Write-Host "Note: winget does not see every installed app (legacy/OEM apps may be missing)." -ForegroundColor DarkGray

    $filter = Read-Host "Filter by name (press Enter for all)"
    if (-not [string]::IsNullOrWhiteSpace($filter)) {
        $AllInstalled = $AllInstalled | Where-Object { $_.Name -like ("*" + $filter + "*") } | Sort-Object Name
    }

    if ($AllInstalled.Count -gt 0) {
        $MenuItems = @()
        foreach ($p in $AllInstalled) {
            $v = if ([string]::IsNullOrWhiteSpace($p.Version)) { "?" } else { $p.Version }
            $s = if ([string]::IsNullOrWhiteSpace($p.Source)) { "" } else { " [" + $p.Source + "]" }
            $MenuItems += [pscustomobject]@{
                Name = ($p.Name + " (v" + $v + ")" + $s)
                _raw = $p
            }
        }

        Show-Menu -Title "Select apps to uninstall first:" -Items $MenuItems
        $uChoice = Read-Host "Uninstall selection (or press Enter to skip)"

        if (-not [string]::IsNullOrWhiteSpace($uChoice)) {
            $uIdx = Parse-Selection -Selection $uChoice -Max $MenuItems.Count

            if ($uIdx.Count -eq 0) {
                Write-Host ("No valid selection. Valid range is 1..{0}." -f $MenuItems.Count) -ForegroundColor Yellow
            }
            else {
                Write-Host ""
                Write-Host "Will uninstall:" -ForegroundColor White
                foreach ($idx in $uIdx) { Write-Host (" - " + $MenuItems[$idx - 1].Name) }
                Write-Host ""

                foreach ($idx in $uIdx) {
                    $pkg = $MenuItems[$idx - 1]._raw
                    $ok = $false
                    try { $ok = Uninstall-Package -Pkg $pkg } catch { $ok = $false }
                    if (-not $ok) { $FailedUninstalls.Add($pkg.Name) | Out-Null }
                }
            }
        }
    }
    else {
        Write-Host "No matches for that filter. Skipping uninstall step." -ForegroundColor Yellow
    }
}
else {
    Write-Host "No winget-detected installed apps found (or output could not be parsed)." -ForegroundColor Yellow
}

# 2) Install dialog (your catalog)
Show-Menu -Title "Select apps to install:" -Items $Apps
$iChoice = Read-Host "Install selection"
$iIdx = Parse-Selection -Selection $iChoice -Max $Apps.Count

if ($iIdx.Count -eq 0) {
    Write-Host "Nothing selected. Exiting." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Will install:" -ForegroundColor White
foreach ($idx in $iIdx) { Write-Host (" - " + $Apps[$idx - 1].Name) }
Write-Host ""

foreach ($idx in $iIdx) {
    $app = $Apps[$idx - 1]
    $ok = $false
    try { $ok = Install-App -Id $app.Id -Name $app.Name -Scope $app.Scope } catch { $ok = $false }
    if (-not $ok) { $FailedInstalls.Add($app.Name) | Out-Null }
}

# 3) Upgrade all at the end
Upgrade-All | Out-Null

# Summary
Write-Host "========== SUMMARY ==========" -ForegroundColor White
if ($FailedUninstalls.Count -gt 0) {
    Write-Host "Uninstall failures:" -ForegroundColor Yellow
    $FailedUninstalls | Sort-Object | ForEach-Object { Write-Host (" - " + $_) -ForegroundColor Yellow }
}
else {
    Write-Host "Uninstall failures: none" -ForegroundColor Green
}

if ($FailedInstalls.Count -gt 0) {
    Write-Host "Install failures:" -ForegroundColor Yellow
    $FailedInstalls | Sort-Object | ForEach-Object { Write-Host (" - " + $_) -ForegroundColor Yellow }
}
else {
    Write-Host "Install failures: none" -ForegroundColor Green
}

Write-Host "All selected actions processed." -ForegroundColor Green
