#!/usr/bin/env bash
set -Eeuo pipefail

# Export current system configs into this repo.
# Matches your layout:
# .
# ├── kde/{kdeglobals,kglobalshortcutsrc,kwinrc}
# ├── shell/gitconfig
# └── vscode/{extensions.txt,keybindings.json,settings.json}

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d_%H%M%S)"
REPO_BACKUP_DIR="${REPO_DIR}/.repo_backup_${STAMP}"

DRY_RUN="false"
AUTO_COMMIT="false"
COMMIT_MSG="chore(export): sync local configs -> repo"

msg()  { printf "\033[1;32m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!! \033[0m%s\n" "$*"; }
die()  { printf "\033[1;31mXX \033[0m%s\n" "$*"; exit 1; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --dry-run        Show what would be copied, but don't write files
  --commit         git add + commit after exporting
  -m "message"     Custom commit message
  -h, --help       Show this help

Examples:
  ./export.sh
  ./export.sh --dry-run
  ./export.sh --commit -m "sync configs"
EOF
}

# ------------------------- Parse args -----------------------------------------
while (( "$#" )); do
  case "$1" in
    --dry-run) DRY_RUN="true"; shift ;;
    --commit)  AUTO_COMMIT="true"; shift ;;
    -m)        COMMIT_MSG="${2:-$COMMIT_MSG}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)         warn "Unknown arg: $1"; shift ;;
  esac
done

ensure_dir() { [[ -d "$1" ]] || { [[ "$DRY_RUN" == "true" ]] || mkdir -p "$1"; }; }
copy_into_repo() {
  local src="$1" dst="$2"
  ensure_dir "$(dirname "$dst")"
  if [[ -e "$dst" ]]; then
    ensure_dir "$REPO_BACKUP_DIR/$(dirname "${dst#"${REPO_DIR}/"}")"
    msg "Backing up repo file: ${dst#"${REPO_DIR}/"} -> .repo_backup_${STAMP}/"
    [[ "$DRY_RUN" == "true" ]] || mv -f "$dst" "$REPO_BACKUP_DIR/$(dirname "${dst#"${REPO_DIR}/"}")/"
  fi
  msg "Export: $src  ->  ${dst#"${REPO_DIR}/"}"
  [[ "$DRY_RUN" == "true" ]] || cp -f "$src" "$dst"
}

# ------------------------- OS-detect paths ------------------------------------
OS="$(uname -s)"
case "$OS" in
  Linux)
    VSCODE_USER_DIR="${HOME}/.config/Code/User"
    KDE_CONFIG_DIR="${HOME}/.config"
    ;;
  Darwin)
    VSCODE_USER_DIR="${HOME}/Library/Application Support/Code/User"
    KDE_CONFIG_DIR="${HOME}/Library/Preferences"  # Rare if on macOS
    ;;
  *)
    warn "Unsupported OS: $OS; defaulting to Linux-like paths."
    VSCODE_USER_DIR="${HOME}/.config/Code/User"
    KDE_CONFIG_DIR="${HOME}/.config"
    ;;
esac

# ------------------------- Exporters ------------------------------------------
export_vscode() {
  local dst_dir="${REPO_DIR}/vscode"
  local settings="${VSCODE_USER_DIR}/settings.json"
  local keys="${VSCODE_USER_DIR}/keybindings.json"

  if [[ -d "$VSCODE_USER_DIR" ]]; then
    [[ -f "$settings" ]] && copy_into_repo "$settings" "${dst_dir}/settings.json" \
      || warn "VS Code settings.json not found at $settings"
    [[ -f "$keys" ]] && copy_into_repo "$keys" "${dst_dir}/keybindings.json" \
      || warn "VS Code keybindings.json not found at $keys"
  else
    warn "VS Code user dir not found: $VSCODE_USER_DIR"
  fi

  # Extensions (requires `code` CLI)
  if command -v code >/dev/null 2>&1; then
    ensure_dir "$dst_dir"
    msg "Export: VS Code extensions -> vscode/extensions.txt"
    if [[ "$DRY_RUN" == "true" ]]; then
      :
    else
      code --list-extensions > "${dst_dir}/extensions.txt" || warn "Failed to list extensions"
    fi
  else
    warn "'code' CLI not found; skipping extensions export."
  fi
}

export_kde() {
  local src_dir="${KDE_CONFIG_DIR}"
  local dst_dir="${REPO_DIR}/kde"
  local files=(kdeglobals kglobalshortcutsrc kwinrc)

  for f in "${files[@]}"; do
    local src="${src_dir}/${f}"
    if [[ -f "$src" ]]; then
      copy_into_repo "$src" "${dst_dir}/${f}"
    else
      warn "KDE file not found: $src"
    fi
  done
}

export_git() {
  local src="${HOME}/.gitconfig"
  local dst="${REPO_DIR}/shell/gitconfig"
  if [[ -f "$src" ]]; then
    copy_into_repo "$src" "$dst"
  else
    warn "~/.gitconfig not found"
  fi
}

# ------------------------- Sanity checks --------------------------------------
[[ -d "${REPO_DIR}/.git" ]] || warn "This directory is not a Git repo (no .git/). Proceeding anyway."
[[ -d "${REPO_DIR}/vscode" ]] || ensure_dir "${REPO_DIR}/vscode"
[[ -d "${REPO_DIR}/kde"    ]] || ensure_dir "${REPO_DIR}/kde"
[[ -d "${REPO_DIR}/shell"  ]] || ensure_dir "${REPO_DIR}/shell"

# ------------------------- Run -------------------------------------------------
msg "Starting export (dry-run: ${DRY_RUN})"
export_vscode
export_kde
export_git
msg "Export complete."

if [[ "$AUTO_COMMIT" == "true" && "$DRY_RUN" != "true" ]]; then
  if command -v git >/dev/null 2>&1; then
    msg "git add/commit"
    git add vscode/ kde/ shell/ || true
    git commit -m "$COMMIT_MSG" || warn "Nothing to commit."
  else
    warn "git not found; skipping commit."
  fi
fi

if [[ -d "$REPO_BACKUP_DIR" ]]; then
  msg "Repo backups stored at: ${REPO_BACKUP_DIR/#$REPO_DIR\//./}"
fi
