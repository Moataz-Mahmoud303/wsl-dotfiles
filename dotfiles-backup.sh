#!/bin/bash
# dotfiles-backup.sh — daily auto-backup to private GitHub repo
# Cron: 0 9,18 * * 1-5 (weekdays 9am and 6pm)
# SECURITY: secrets/certs/tokens are stripped before any file is committed

set -euo pipefail

BACKUP_DIR="$HOME/.dotfiles-backup"
LOG="$HOME/.dotfiles-backup.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

echo "[$TIMESTAMP] Starting dotfiles backup..." >> "$LOG"

# ── Plain copy (no secrets in these files) ────────────────────────────────
PLAIN_FILES=(
    ".bashrc"
    ".bash_profile"
    ".gitconfig"
    ".aws/config"        # SSO profile config only — no credentials/tokens
)

for f in "${PLAIN_FILES[@]}"; do
    src="$HOME/$f"
    dest="$BACKUP_DIR/$f"
    if [ -f "$src" ]; then
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
    fi
done

# ── Kube config — strip ALL secret fields before saving ───────────────────
KUBE_SRC="$HOME/.kube/config"
KUBE_DEST="$BACKUP_DIR/.kube/config"
if [ -f "$KUBE_SRC" ]; then
    mkdir -p "$(dirname "$KUBE_DEST")"
    # Remove lines containing certs, keys, or bearer tokens
    sed '/certificate-authority-data:/d
         /client-certificate-data:/d
         /client-key-data:/d
         /token:/d' "$KUBE_SRC" > "$KUBE_DEST"
    echo "[$TIMESTAMP] kube/config saved (secrets stripped)" >> "$LOG"
fi

# ── SSH config (public info only — never private keys) ───────────────────
SSH_CONFIG="$HOME/.ssh/config"
SSH_DEST="$BACKUP_DIR/.ssh/config"
if [ -f "$SSH_CONFIG" ]; then
    mkdir -p "$(dirname "$SSH_DEST")"
    cp "$SSH_CONFIG" "$SSH_DEST"
    echo "[$TIMESTAMP] .ssh/config saved" >> "$LOG"
fi
# Explicitly never copy private keys
# (*.pem, id_rsa, id_ed25519, etc. are never touched)

# ── Keep the script itself up to date ────────────────────────────────────
cp "$HOME/.dotfiles-backup.sh" "$BACKUP_DIR/dotfiles-backup.sh" 2>/dev/null || true

# ── Commit & push if anything changed ────────────────────────────────────
cd "$BACKUP_DIR"
git add -A

if ! git diff --cached --quiet; then
    git -c user.email="moataz.mahmoud@woodside.com.au" \
        -c user.name="Moataz-Mahmoud303" \
        commit -m "backup($(hostname -s)): dotfiles snapshot $(date '+%Y-%m-%d %H:%M')"

    if git push origin main 2>>"$LOG"; then
        echo "[$TIMESTAMP] ✓ Pushed to github.com/Moataz-Mahmoud303/wsl-dotfiles" >> "$LOG"
    else
        echo "[$TIMESTAMP] ✗ Push failed (will retry next run)" >> "$LOG"
    fi
else
    echo "[$TIMESTAMP] No changes." >> "$LOG"
fi
