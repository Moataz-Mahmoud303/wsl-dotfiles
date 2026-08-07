# Windows-side setup for VS Code Remote-SSH to AWAUBDEV01112
# Run this in PowerShell
# Prerequisites: WSL with Ubuntu already set up
#
# Usage: .\win-remote-ssh-setup.ps1
#   or:  Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Moataz-Mahmoud303/wsl-dotfiles/main/win-remote-ssh-setup.ps1" -OutFile "$env:TEMP\setup.ps1"; & "$env:TEMP\setup.ps1"

# Detect WOPID from Windows username
$wopid = $env:USERNAME.ToLower()
Write-Host "Setting up Remote-SSH for user: $wopid" -ForegroundColor Cyan

# 1. Install AWS CLI (skip if already installed)
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "[+] Installing AWS CLI..." -ForegroundColor Yellow
    Start-Process msiexec.exe -ArgumentList '/i https://awscli.amazonaws.com/AWSCLIV2.msi /quiet' -Wait
    $env:PATH = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
} else {
    Write-Host "[ok] AWS CLI already installed: $(aws --version)" -ForegroundColor Green
}

# 2. Install Session Manager Plugin (skip if already installed)
if (-not (Get-Command session-manager-plugin -ErrorAction SilentlyContinue)) {
    Write-Host "[+] Installing Session Manager Plugin..." -ForegroundColor Yellow
    $ssmUrl = "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe"
    Invoke-WebRequest -Uri $ssmUrl -OutFile "$env:TEMP\SessionManagerPluginSetup.exe"
    Start-Process "$env:TEMP\SessionManagerPluginSetup.exe" -ArgumentList '/quiet' -Wait
    $env:PATH = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
} else {
    Write-Host "[ok] Session Manager Plugin already installed." -ForegroundColor Green
}

# 3. Verify installs
aws --version
session-manager-plugin --version

# 4. Create .aws\config
mkdir "$env:USERPROFILE\.aws" -Force | Out-Null
if (-not (Test-Path "$env:USERPROFILE\.aws\config") -or -not (Select-String -Path "$env:USERPROFILE\.aws\config" -Pattern "sso-session woodside" -Quiet)) {
    Write-Host "[+] Writing AWS SSO config..." -ForegroundColor Yellow
    Set-Content -Path "$env:USERPROFILE\.aws\config" -Value @"
[sso-session woodside]
sso_start_url = https://d-976710a35d.awsapps.com/start#/
sso_region = ap-southeast-2
sso_registration_scopes = sso:account:access

[profile wpl-wrk-dstools-prd]
sso_session = woodside
sso_account_id = 312551735264
sso_role_name = cops-permset-teamadmin
region = ap-southeast-2
output = json
"@
} else {
    Write-Host "[ok] AWS config already has sso-session woodside." -ForegroundColor Green
}

# 5. Generate Windows SSH key (use _dev suffix to avoid permission lockout on id_ed25519)
mkdir "$env:USERPROFILE\.ssh" -Force | Out-Null
$keyFile = "$env:USERPROFILE\.ssh\id_ed25519_dev"
if (-not (Test-Path $keyFile)) {
    Write-Host "[+] Generating Windows SSH key..." -ForegroundColor Yellow
    ssh-keygen -t ed25519 -f $keyFile -N '""'
} else {
    Write-Host "[ok] SSH key already exists: $keyFile" -ForegroundColor Green
}

# 6. Create .ssh\config with ProxyCommand (auto-detect WOPID)
Write-Host "[+] Writing SSH config..." -ForegroundColor Yellow
Set-Content -Path "$env:USERPROFILE\.ssh\config" -Value @"
Host awaubdev01112
    HostName i-00d70946cb4d92dad
    User $wopid
    IdentityFile ~/.ssh/id_ed25519_dev
    ProxyCommand C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p --profile wpl-wrk-dstools-prd --region ap-southeast-2"
"@

# 7. Login
Write-Host "`n[+] Logging in to AWS SSO..." -ForegroundColor Yellow
aws sso login --profile wpl-wrk-dstools-prd

# 8. Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[ok] Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Your Windows SSH public key:" -ForegroundColor Yellow
Get-Content "$keyFile.pub"
Write-Host ""
Write-Host "  Send the key above to your team lead to get added to AWAUBDEV01112." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Then: Restart VS Code -> Ctrl+Shift+P -> 'Remote-SSH: Connect to Host' -> awaubdev01112" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
