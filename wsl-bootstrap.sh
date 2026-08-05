#!/usr/bin/env bash
# WSL New Starter Bootstrap Script — Woodside Data Science
# Run this ONCE inside a fresh Ubuntu WSL after completing the Windows-side steps:
#   1. wsl --install -d Ubuntu (and created your user)
#   2. Created C:\Users\<you>\.wslconfig with VirtioProxy+dnsTunneling
#   3. wsl --shutdown + reopened Ubuntu
#
# Usage: bash wsl-bootstrap.sh
# (do NOT run with sudo — the script calls sudo internally where needed)

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

msg_ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
msg_warn() { echo -e "${YELLOW}[!]${NC} $*"; }
msg_err()  { echo -e "${RED}[✗]${NC} $*"; }

# ─── 1. APT PACKAGES ─────────────────────────────────────────────────────────
msg_ok "Updating apt and installing base packages..."
sudo apt update -qq
sudo apt install -y -qq \
  python3 python3-pip python3-venv \
  unzip curl wget git jq \
  build-essential libssl-dev libffi-dev python3-dev \
  ca-certificates openssh-client

# ─── 2. AWS CLI v2 ───────────────────────────────────────────────────────────
if command -v aws &>/dev/null; then
  msg_ok "AWS CLI already installed: $(aws --version)"
else
  msg_ok "Installing AWS CLI v2..."
  cd /tmp
  curl -sS "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
  unzip -qo awscliv2.zip
  sudo ./aws/install
  rm -rf aws awscliv2.zip
  cd ~
  msg_ok "AWS CLI installed: $(aws --version)"
fi

# ─── 3. SESSION MANAGER PLUGIN ──────────────────────────────────────────────
if command -v session-manager-plugin &>/dev/null; then
  msg_ok "Session Manager Plugin already installed."
else
  msg_ok "Installing AWS Session Manager Plugin..."
  cd /tmp
  curl -sS "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o session-manager-plugin.deb
  sudo dpkg -i session-manager-plugin.deb
  rm -f session-manager-plugin.deb
  cd ~
  msg_ok "Session Manager Plugin installed."
fi

# ─── 4. FIX DNS / RESOLV.CONF ────────────────────────────────────────────────
msg_ok "Checking DNS configuration..."

# Check if dnsTunneling is being blocked by GSA
NEEDS_MANUAL_DNS=false
if grep -q "generateResolvConf = false" /etc/wsl.conf 2>/dev/null; then
  msg_ok "resolv.conf already set to manual (generateResolvConf=false)."
elif ! getent hosts login.microsoftonline.com &>/dev/null; then
  msg_warn "Cannot resolve login.microsoftonline.com — applying manual DNS fix."
  NEEDS_MANUAL_DNS=true
else
  msg_ok "DNS working (login.microsoftonline.com resolves). No fix needed."
fi

if [[ "$NEEDS_MANUAL_DNS" == "true" ]]; then
  # Set generateResolvConf = false
  if grep -q '^\[network\]' /etc/wsl.conf 2>/dev/null; then
    sudo sed -i 's/generateResolvConf = true/generateResolvConf = false/' /etc/wsl.conf
  else
    sudo tee -a /etc/wsl.conf > /dev/null <<'EOF'

[network]
generateResolvConf = false
EOF
  fi

  # Write corporate DNS
  sudo chattr -i /etc/resolv.conf 2>/dev/null || true
  sudo rm -f /etc/resolv.conf
  sudo tee /etc/resolv.conf > /dev/null <<'EOF'
nameserver 10.240.26.224
nameserver 10.240.26.225
nameserver 10.250.40.5
nameserver 8.8.8.8
nameserver 1.1.1.1
options timeout:2 attempts:2
EOF
  msg_warn "DNS fix applied. After this script finishes, run 'wsl --shutdown' from Windows PowerShell, then reopen Ubuntu."
fi

# ─── 5. SSH KEY ──────────────────────────────────────────────────────────────
if [[ -f ~/.ssh/id_ed25519 ]]; then
  msg_ok "SSH key already exists: ~/.ssh/id_ed25519"
else
  msg_ok "Generating SSH key..."
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
  msg_ok "SSH key generated."
fi
echo ""
msg_ok "Your public key (send this to your team lead for server access):"
echo -e "${YELLOW}"
cat ~/.ssh/id_ed25519.pub
echo -e "${NC}"

# ─── 6. AWS CONFIG (TEMPLATE) ────────────────────────────────────────────────
mkdir -p ~/.aws
if [[ -f ~/.aws/config ]] && grep -q 'sso-session woodside' ~/.aws/config 2>/dev/null; then
  msg_ok "AWS config already has [sso-session woodside]. Skipping."
else
  msg_ok "Writing AWS SSO config template..."
  cat >> ~/.aws/config <<'EOF'
[sso-session woodside]
sso_start_url = https://d-976710a35d.awsapps.com/start#/
sso_region = ap-southeast-2
sso_registration_scopes = sso:account:access

[profile wpl-wrk-dstools-np]
sso_session = woodside
sso_account_id = 891259374574
sso_role_name = cops-permset-teamadmin
region = ap-southeast-2
output = json

[profile wpl-wrk-dstools-prd]
sso_session = woodside
sso_account_id = 312551735264
sso_role_name = cops-permset-teamadmin
region = ap-southeast-2
output = json
EOF
  msg_ok "AWS config written. Edit ~/.aws/config to add/change profiles for your team."
fi

# ─── 7. PYTHON VENV ─────────────────────────────────────────────────────────
VENV_DIR="$HOME/.venv"
if [[ -d "$VENV_DIR" ]]; then
  msg_ok "Python venv already exists at $VENV_DIR"
else
  msg_ok "Creating Python virtual environment at $VENV_DIR..."
  python3 -m venv "$VENV_DIR"
  msg_ok "venv created. Activate with: source ~/.venv/bin/activate"
fi

# ─── 8. BASHRC ADDITIONS ────────────────────────────────────────────────────
MARKER="# --- wsl-bootstrap additions ---"
if grep -qF "$MARKER" ~/.bashrc 2>/dev/null; then
  msg_ok ".bashrc additions already present."
else
  msg_ok "Adding helpful defaults to ~/.bashrc..."
  cat >> ~/.bashrc <<'EOF'

# --- wsl-bootstrap additions ---
# Activate default venv
[ -d "$HOME/.venv" ] && source "$HOME/.venv/bin/activate"

# AWS defaults
export AWS_PROFILE=wpl-wrk-dstools-np
export AWS_REGION=ap-southeast-2

# Refresh Woodside SSO (all profiles sharing sso-session=woodside)
alias awslogin='aws sso login --sso-session woodside && aws sts get-caller-identity'

# Prompt with git branch
parse_git_branch() { git branch 2>/dev/null | sed -n "s/* \(.*\)/ (\1)/p"; }
export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[33m\]$(parse_git_branch)\[\033[00m\]\$ '
EOF
  msg_ok ".bashrc updated."
fi

# ─── 9. SUMMARY ─────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════"
msg_ok "Bootstrap complete! Next steps:"
echo ""
if [[ "$NEEDS_MANUAL_DNS" == "true" ]]; then
  echo "  1. From Windows PowerShell: wsl --shutdown"
  echo "  2. Reopen Ubuntu"
  echo "  3. Run: awslogin"
else
  echo "  1. Run: source ~/.bashrc"
  echo "  2. Run: awslogin    (opens browser — sign in with your CSA account)"
fi
echo ""
echo "  Then verify:  aws sts get-caller-identity"
echo ""
echo "  Your SSH public key (above) — send to your team lead to get"
echo "  added to the dev server (AWAUBDEV01112)."
echo "════════════════════════════════════════════════════════════════"
