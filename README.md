# WSL2 Dotfiles Backup

Auto-backed up daily via cron from `WEL-PF5NQY5Q`.

## Files
| File | Purpose |
|------|---------|
| `.bashrc` | Shell config, aliases, awslogin, ktools, proxy |
| `.bash_profile` | Login shell loader |
| `.gitconfig` | Git identity |
| `.aws/config` | AWS SSO profiles (50 profiles, no credentials) |
| `dotfiles-backup.sh` | The backup script itself |

## Restore
```bash
# Clone and restore
git clone https://github.com/Moataz-Mahmoud303/wsl-dotfiles ~/dotfiles-restore
cp ~/dotfiles-restore/.bashrc ~/.bashrc
cp ~/dotfiles-restore/.bash_profile ~/.bash_profile
cp ~/dotfiles-restore/.gitconfig ~/.gitconfig
mkdir -p ~/.aws && cp ~/dotfiles-restore/.aws/config ~/.aws/config
source ~/.bashrc
```
