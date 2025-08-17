```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# Run from repo root.
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${HOME}/.dotfiles_backup_${STAMP}"

msg()  { printf "\033[1;32m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!! \033[0m%s\n" "$*"; }

ensure_dir() { [[ -d "$1" ]] || mkdir -p "$1"; }

backup_if_exists() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    ensure_dir "$BACKUP_DIR"
    mv -f "$target" "$BACKUP_DIR"/
    msg "Backed up $target -> $BACKUP_DIR/"
  fi
}

link_file() {
  local src="$1" dst="$2"
  ensure_dir "$(dirname "$dst")"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    msg "Already linked: $dst"
    return 0
  fi
  backup_if_exists "$dst"
  ln -s "$src" "$dst"
  msg "Linked $dst -> $src"
}

# ------------------------- OS-specific paths ----------------------------------
OS="$(uname -s)"
case "$OS" in
  Linux)
    VSCODE_USER_DIR="${HOME}/.config/Code/User"
    KDE_CONFIG_DIR="${HOME}/.config"
    ;;
  Darwin) # macOS
    VSCODE_USER_DIR="${HOME}/Library/Application Support/Code/User"
    KDE_CONFIG_DIR="${HOME}/Library/Preferences"  # KDE uncommon on macOS
    ;;
  *)
    warn "Unsupported OS: $OS; using Linux-like defaults."
    VSCODE_USER_DIR="${HOME}/.config/Code/User"
    KDE_CONFIG_DIR="${HOME}/.config"
    ;;
esac

# ------------------------- VS Code --------------------------------------------
restore_vscode() {
  local src_dir="${DOTFILES_DIR}/vscode"
  [[ -d "$src_dir" ]] || { warn "vscode/ not found; skipping."; return; }

  msg "Restoring VS Code settings -> $VSCODE_USER_DIR"
  ensure_dir "$VSCODE_USER_DIR"

  # settings & keybindings
  [[ -f "${src_dir}/settings.json"    ]] && link_file "${src_dir}/settings.json"    "${VSCODE_USER_DIR}/settings.json"
  [[ -f "${src_dir}/keybindings.json" ]] && link_file "${src_dir}/keybindings.json" "${VSCODE_USER_DIR}/keybindings.json"

  # extensions
  if [[ -f "${src_dir}/extensions.txt" ]]; then
    if command -v code >/dev/null 2>&1; then
      msg "Installing VS Code extensions from vscode/extensions.txt ..."
      while read -r ext; do
        [[ -z "$ext" || "$ext" =~ ^# ]] && continue
        code --install-extension "$ext" || warn "Failed to install: $ext"
      done < "${src_dir}/extensions.txt"
    else
      warn "'code' CLI not found; skipping extension install."
    fi
  fi
}

# ------------------------- KDE ------------------------------------------------
restore_kde() {
  local src_dir="${DOTFILES_DIR}/kde"
  [[ -d "$src_dir" ]] || { warn "kde/ not found; skipping."; return; }

  msg "Restoring KDE configs -> ${KDE_CONFIG_DIR}"
  for f in kdeglobals kglobalshortcutsrc kwinrc; do
    [[ -f "${src_dir}/${f}" ]] && link_file "${src_dir}/${f}" "${KDE_CONFIG_DIR}/${f}"
  done
  msg "KDE done. You may need to restart Plasma or log out/in."
}

# ------------------------- Git ------------------------------------------------
restore_git() {
  local src="${DOTFILES_DIR}/shell/gitconfig"
  [[ -f "$src" ]] || { warn "shell/gitconfig not found; skipping gitconfig."; return; }
  msg "Restoring ~/.gitconfig"
  link_file "$src" "${HOME}/.gitconfig"
}

# ------------------------- Run ------------------------------------------------
msg "Starting restore from: $DOTFILES_DIR"
restore_vscode
restore_kde
restore_git
msg "All done 🎉"
[[ -d "$BACKUP_DIR" ]] && msg "Backups saved in: $BACKUP_DIR"
