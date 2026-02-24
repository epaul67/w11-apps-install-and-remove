# Windows 11 Apps Install & Remove Script

Provision a fresh Windows 11 machine in minutes using WinGet.

This script installs a practical base set of applications such as browsers, developer tools, remote access utilities, productivity apps, and more.

It is interactive, customizable, and designed for repeatable system setup.

---

## ✨ Features

- Uses native **WinGet** (built into Windows 11)
- Interactive install selection
- Optional uninstall of existing applications
- Handles MSIX / Appx removal when needed
- Automatically repairs WinGet sources on errors
- Forces `winget` source to avoid Microsoft Store issues
- Runs `winget upgrade --all` after installation
- Continues execution even if individual installs fail
- Displays summary of failures at completion

---

## 🖥️ Requirements

- Windows 11
- WinGet (Microsoft App Installer installed)
- PowerShell 5.1 or later
- Administrator privileges recommended

Verify WinGet:

```powershell
winget --version
```

If not installed, install **App Installer** from Microsoft Store.

---

## ▶ Usage

### Recommended (wrapper)

```cmd
run-install.cmd
```

This bypasses PowerShell execution policy for the session.

### Manual

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install-tools.ps1
```

---

## 🧩 Customizing the App List

Edit the `$Apps` array inside `install-tools.ps1`:

```powershell
$Apps = @(
    [pscustomobject]@{ Name="Google Chrome"; Id="Google.Chrome"; Scope="machine" },
    [pscustomobject]@{ Name="Visual Studio Code"; Id="Microsoft.VisualStudioCode"; Scope="" },
    [pscustomobject]@{ Name="Git"; Id="Git.Git"; Scope="" }
)
```

Find package IDs with:

```powershell
winget search <app-name>
```

---

## 🔄 Automatic WinGet Repair

If WinGet fails (for example due to `msstore` certificate errors), the script automatically runs:

```powershell
winget source remove msstore
winget source reset --force
winget source remove msstore
winget source update
```

Then retries the failed operation once.

---

## ⬆ Upgrade Phase

After installation completes, the script runs:

```powershell
winget upgrade --all
```

This ensures all installed packages are updated.

---

## ⚠ Failure Handling

- Install/uninstall actions return success/failure
- Script does not stop on first error
- A summary of failed actions is printed at the end

---

## 💾 Disk Space Notes

Some packages (Docker, WSL, large updates) may temporarily use significant disk space.

To clean up:

```powershell
cleanmgr
```

or:

```powershell
Dism.exe /Online /Cleanup-Image /StartComponentCleanup
```

---

## 🛠 Typical Use Cases

- Fresh Windows 11 setup
- Developer workstation bootstrap
- Personal base install
- Reinstall after clean OS deployment
