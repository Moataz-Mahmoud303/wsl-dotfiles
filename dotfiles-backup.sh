#!/bin/bash
# dotfiles-backup.sh — auto-backup critical config files to git
# Runs via cron; commits and pushes changes to the dotfiles branch in your home repo

set -euo pipefail

BACKUP_DIR="$HOME/.dotfiles-backup"
REPO_URL="https://github.com/Moataz-Mahmoud303/project-dashboard-PCC.git"
BRANCH="dotfiles-backup"
LOG="$HOME/.dotfiles-backup.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Files/dirs to back up (sensitive content is excluded — no credentials)
DOTFILES=(
    ".bashrc"
    ".bash_profile"
    ".gitconfig"
    ".aws/config"       # SSO config only — NO credentials/sso cache
)

echo "[$TIMESTAMP] Starting dotfiles backup..." >> "$LOG"

# ── Init backup repo ────────────────────────────────────────────────────────
if [ ! -d "$BACKUP_DIR/.git" ]; then
    mkdir -p "$BACKUP_DIR"
    git -C "$BACKUP_DIR" init -b "$BRANCH" 2>/dev/null || git -C "$BACKUP_DIR" init
    git -C "$BACKUP_DIR" remote add origin "$REPO_URL" 2>/dev/null || true
    echo "[$TIMESTAMP] Initialised backup repo at $BACKUP_DIR" >> "$LOG"
fi

# ── Copy dotfiles into backup repo ─────────────────────────────────────────
for f in "${DOTFILES[@]}"; do
    src="$HOME/$f"
    dest="$BACKUP_DIR/$f"
    if [ -f "$src" ]; then
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
    fi
done

# ── Commit if there are changes ────────────────────────────────────────────
cd "$BACKUP_DIR"
git add -A

if ! git diff --cached --quiet; then
    HOSTNAME_SHORT=$(hostname -s 2>/dev/null || echo "wsl")
    git -c user.email="moataz.mahmoud@woodside.com.au" \
        -c user.name="Moataz-Mahmoud303" \
        commit -m "backup($HOSTNAME_SHORT): dotfiles snapshot $(date '+%Y-%m-%d %H:%M')"

    # Push — requires git credentials configured (GH CLI or token)
    if git push origin "$BRANCH" --force-with-lease 2>>"$LOG"; then
        echo "[$TIMESTAMP] ✓ Pushed to $BRANCH" >> "$LOG"
    else
        echo "[$TIMESTAMP] ✗ Push failed (will retry next run)" >> "$LOG"
    fi
else
    echo "[$TIMESTAMP] No changes to commit." >> "$LOG"
fi
