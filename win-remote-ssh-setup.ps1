# Windows-side setup for VS Code Remote-SSH to AWAUBDEV01112
# Run this in PowerShell (as Admin recommended for installs)
# Prerequisites: WSL with Ubuntu already set up and SSH key generated

# 1. Install AWS CLI
Start-Process msiexec.exe -ArgumentList '/i https://awscli.amazonaws.com/AWSCLIV2.msi /quiet' -Wait

# 2. Install Session Manager Plugin
$ssmUrl = "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe"
Invoke-WebRequest -Uri $ssmUrl -OutFile "$env:TEMP\SessionManagerPluginSetup.exe"
Start-Process "$env:TEMP\SessionManagerPluginSetup.exe" -ArgumentList '/quiet' -Wait

# 3. Refresh PATH so aws is found in this session
$env:PATH = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# 4. Verify installs
aws --version
session-manager-plugin --version

# 5. Create .aws\config
mkdir "$env:USERPROFILE\.aws" -Force | Out-Null
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

# 6. Create .ssh\config with ProxyCommand
mkdir "$env:USERPROFILE\.ssh" -Force | Out-Null
Set-Content -Path "$env:USERPROFILE\.ssh\config" -Value @"
Host awaubdev01112
    HostName i-00d70946cb4d92dad
    User YOURWOPID
    IdentityFile ~/.ssh/id_ed25519
    ProxyCommand C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p --profile wpl-wrk-dstools-prd --region ap-southeast-2"
"@

# 7. Copy SSH key from WSL to Windows (so IdentityFile works)
wsl cat ~/.ssh/id_ed25519 | Set-Content "$env:USERPROFILE\.ssh\id_ed25519" -NoNewline
wsl cat ~/.ssh/id_ed25519.pub | Set-Content "$env:USERPROFILE\.ssh\id_ed25519.pub" -NoNewline

# 8. Login
aws sso login --profile wpl-wrk-dstools-prd

Write-Host "`n✓ Done! Restart VS Code, then Ctrl+Shift+P → 'Remote-SSH: Connect to Host' → awaubdev01112" -ForegroundColor Green
Write-Host "  NOTE: Edit C:\Users\$env:USERNAME\.ssh\config and replace 'YOURWOPID' with your actual WOPID (e.g. wa11np)" -ForegroundColor Yellow
