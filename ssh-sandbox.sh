#!/usr/bin/env bash
# Quick SSH setup for AWAUBDEV01112 (DS Sandbox)
# Run: bash <(curl -sS https://raw.githubusercontent.com/Moataz-Mahmoud303/wsl-dotfiles/main/ssh-sandbox.sh)
set -euo pipefail
WOPID=$(whoami)
echo "[+] Setting up SSH to AWAUBDEV01112 for $WOPID"

# Session Manager Plugin
command -v session-manager-plugin &>/dev/null || {
  echo "[+] Installing Session Manager Plugin..."
  curl -sS "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o /tmp/ssm.deb
  sudo dpkg -i /tmp/ssm.deb && rm -f /tmp/ssm.deb
}

# SSH key
[ -f ~/.ssh/id_ed25519 ] || { mkdir -p ~/.ssh && chmod 700 ~/.ssh && ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519; }

# AWS config — add sso-session + dstools-prd if missing
mkdir -p ~/.aws
grep -q 'sso-session woodside' ~/.aws/config 2>/dev/null || cat >> ~/.aws/config << 'EOF'
[sso-session woodside]
sso_start_url = https://d-976710a35d.awsapps.com/start#/
sso_region = ap-southeast-2
sso_registration_scopes = sso:account:access
EOF
grep -q 'profile wpl-wrk-dstools-prd' ~/.aws/config 2>/dev/null || cat >> ~/.aws/config << 'EOF'

[profile wpl-wrk-dstools-prd]
sso_session = woodside
sso_account_id = 312551735264
sso_role_name = cops-permset-teamadmin
region = ap-southeast-2
output = json
EOF

# SSH config
mkdir -p ~/.ssh && chmod 700 ~/.ssh
grep -q 'awaubdev01112' ~/.ssh/config 2>/dev/null || cat >> ~/.ssh/config << EOF
Host awaubdev01112
    HostName i-00d70946cb4d92dad
    User $WOPID
    IdentityFile ~/.ssh/id_ed25519
    ProxyCommand aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p --profile wpl-wrk-dstools-prd --region ap-southeast-2
EOF
chmod 600 ~/.ssh/config

echo ""
echo "[ok] Done. Your public key:"
cat ~/.ssh/id_ed25519.pub
echo ""
echo "Send the key above to Moataz, then run:"
echo "  aws sso login --profile wpl-wrk-dstools-prd"
echo "  ssh awaubdev01112"
