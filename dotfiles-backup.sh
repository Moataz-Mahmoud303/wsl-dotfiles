#!/bin/bash
# dotfiles-backup.sh — daily auto-backup to private GitHub repo
# Cron: 0 18 * * 1-5 (weekdays at 6pm)

set -euo pipefail

BACKUP_DIR="$HOME/.dotfiles-backup"
LOG="$HOME/.dotfiles-backup.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

DOTFILES=(
    ".bashrc"
    ".bash_profile"
    ".gitconfig"
    ".aws/config"
)

echo "[$TIMESTAMP] Starting dotfiles backup..." >> "$LOG"

for f in "${DOTFILES[@]}"; do
    src="$HOME/$f"
    dest="$BACKUP_DIR/$f"
    if [ -f "$src" ]; then
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
    fi
done

# Also keep the script itself up to date
cp "$HOME/.dotfiles-backup.sh" "$BACKUP_DIR/dotfiles-backup.sh" 2>/dev/null || true

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
