# Giovanni’s Dotfiles

Configs for my workstation: **KDE**, **VS Code**, and **Git**.


## What this does
- Symlinks config files into the correct locations (backs up any existing files first).
- Installs VS Code extensions from `vscode/extensions.txt`.

## Requirements
- Linux/macOS (Windows WSL also works)
- Bash
- (Optional) VS Code CLI `code` in PATH to auto-install extensions

## Restore on a new system
```bash
git clone https://github.com/giovannicampa/dotfiles.git
cd dotfiles

# From your repo root
chmod +x export.sh

# Preview changes (no writes):
./export.sh --dry-run

# Export and commit:
./export.sh --commit -m "sync configs"
