#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# macOS Dev Terminal Bootstrap
# Stack: Homebrew + Oh My Zsh + tmux + Starship + Ghostty
# Author: local bootstrap
# ============================================================

readonly NOW="$(date +%Y%m%d_%H%M%S)"
readonly BACKUP_DIR="${HOME}/.terminal-bootstrap-backup/${NOW}"
readonly ZSHRC="${HOME}/.zshrc"
readonly TMUX_CONF="${HOME}/.tmux.conf"
readonly STARSHIP_CONFIG_DIR="${HOME}/.config"
readonly STARSHIP_CONFIG="${STARSHIP_CONFIG_DIR}/starship.toml"
readonly TPM_DIR="${HOME}/.tmux/plugins/tpm"

log() {
  printf "\033[1;32m[INFO]\033[0m %s\n" "$*"
}

warn() {
  printf "\033[1;33m[WARN]\033[0m %s\n" "$*"
}

err() {
  printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2
}

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    err "이 스크립트는 macOS 전용입니다."
    exit 1
  fi
}

backup_file() {
  local file="$1"

  if [[ -f "$file" ]]; then
    mkdir -p "$BACKUP_DIR"
    cp "$file" "${BACKUP_DIR}/$(basename "$file")"
    log "백업 완료: $file -> ${BACKUP_DIR}/$(basename "$file")"
  fi
}

install_homebrew_if_needed() {
  if command -v brew >/dev/null 2>&1; then
    log "Homebrew 이미 설치됨: $(brew --version | head -n 1)"
    return
  fi

  log "Homebrew 설치 시작"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Apple Silicon / Intel 경로 모두 처리
  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    err "Homebrew 설치 후 brew 경로를 찾지 못했습니다."
    exit 1
  fi
}

ensure_brew_in_shell() {
  local brew_shellenv=""

  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    brew_shellenv='eval "$(/opt/homebrew/bin/brew shellenv)"'
  elif [[ -x "/usr/local/bin/brew" ]]; then
    brew_shellenv='eval "$(/usr/local/bin/brew shellenv)"'
  else
    warn "brew shellenv 경로를 찾지 못했습니다."
    return
  fi

  touch "$ZSHRC"

  if ! grep -Fq "$brew_shellenv" "$ZSHRC"; then
    {
      echo ""
      echo "# >>> homebrew init >>>"
      echo "$brew_shellenv"
      echo "# <<< homebrew init <<<"
    } >> "$ZSHRC"
    log ".zshrc에 Homebrew shellenv 추가"
  fi
}

brew_install_packages() {
  log "brew update 실행"
  brew update

  local packages=(
    git
    zsh
    tmux
    starship
    fzf
    eza
    zoxide
  )

  for pkg in "${packages[@]}"; do
    if brew list "$pkg" >/dev/null 2>&1; then
      log "이미 설치됨: $pkg"
    else
      log "설치 중: $pkg"
      brew install "$pkg"
    fi
  done

  if brew list --cask ghostty >/dev/null 2>&1; then
    log "Ghostty 이미 설치됨"
  else
    log "Ghostty 설치 중"
    brew install --cask ghostty
  fi
}

install_oh_my_zsh() {
  if [[ -d "${HOME}/.oh-my-zsh" ]]; then
    log "Oh My Zsh 이미 설치됨"
    return
  fi

  log "Oh My Zsh unattended 설치 시작"

  # KEEP_ZSHRC=yes: 기존 .zshrc 보존
  # RUNZSH=no, CHSH=no: 설치 중 shell 전환/실행 방지
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

install_zsh_plugins() {
  local custom_dir="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}"

  mkdir -p "${custom_dir}/plugins"

  if [[ ! -d "${custom_dir}/plugins/zsh-autosuggestions" ]]; then
    log "zsh-autosuggestions 설치"
    git clone https://github.com/zsh-users/zsh-autosuggestions \
      "${custom_dir}/plugins/zsh-autosuggestions"
  else
    log "zsh-autosuggestions 이미 설치됨"
  fi

  if [[ ! -d "${custom_dir}/plugins/zsh-syntax-highlighting" ]]; then
    log "zsh-syntax-highlighting 설치"
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
      "${custom_dir}/plugins/zsh-syntax-highlighting"
  else
    log "zsh-syntax-highlighting 이미 설치됨"
  fi
}

patch_zshrc() {
  backup_file "$ZSHRC"
  touch "$ZSHRC"

  # Oh My Zsh 기본 로딩 블록
  if ! grep -Fq "# >>> oh-my-zsh bootstrap >>>" "$ZSHRC"; then
    cat >> "$ZSHRC" <<'EOF'

# >>> oh-my-zsh bootstrap >>>
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""

plugins=(
  git
  docker
  npm
  macos
  tmux
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"
# <<< oh-my-zsh bootstrap <<<
EOF
    log ".zshrc에 Oh My Zsh 설정 추가"
  else
    log ".zshrc Oh My Zsh 블록 이미 존재"
  fi

  # Starship init은 Oh My Zsh 이후에 위치해야 prompt 충돌이 적다.
  if ! grep -Fq 'eval "$(starship init zsh)"' "$ZSHRC"; then
    cat >> "$ZSHRC" <<'EOF'

# >>> starship prompt >>>
eval "$(starship init zsh)"
# <<< starship prompt <<<
EOF
    log ".zshrc에 Starship init 추가"
  else
    log ".zshrc Starship init 이미 존재"
  fi

  # zoxide/fzf/eza 편의 alias
  if ! grep -Fq "# >>> cli quality-of-life >>>" "$ZSHRC"; then
    cat >> "$ZSHRC" <<'EOF'

# >>> cli quality-of-life >>>
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
command -v fzf >/dev/null 2>&1 && source <(fzf --zsh)

alias ls='eza --icons --group-directories-first'
alias ll='eza -lah --icons --group-directories-first'
alias la='eza -a --icons --group-directories-first'
alias ..='cd ..'
alias ...='cd ../..'
# <<< cli quality-of-life <<<
EOF
    log ".zshrc에 CLI 편의 설정 추가"
  else
    log ".zshrc CLI 편의 블록 이미 존재"
  fi
}

write_starship_config() {
  backup_file "$STARSHIP_CONFIG"
  mkdir -p "$STARSHIP_CONFIG_DIR"

  cat > "$STARSHIP_CONFIG" <<'EOF'
# ~/.config/starship.toml

add_newline = true
command_timeout = 1000

format = """
$directory\
$git_branch\
$git_status\
$java\
$nodejs\
$docker_context\
$kubernetes\
$cmd_duration\
$line_break\
$character"""

[directory]
truncation_length = 4
truncate_to_repo = false
read_only = " 󰌾"

[git_branch]
symbol = " "
format = "[$symbol$branch]($style) "
style = "bold purple"

[git_status]
format = '([$all_status$ahead_behind]($style) )'
style = "bold red"

[java]
symbol = "☕ "
format = "[$symbol($version)]($style) "
style = "bold red"

[nodejs]
symbol = "⬢ "
format = "[$symbol($version)]($style) "
style = "bold green"

[docker_context]
symbol = "🐳 "
format = "[$symbol$context]($style) "
style = "blue bold"

[kubernetes]
disabled = false
symbol = "☸ "
format = "[$symbol$context( \($namespace\))]($style) "
style = "cyan bold"

[cmd_duration]
min_time = 1000
format = "took [$duration]($style) "
style = "yellow"

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"
vimcmd_symbol = "[❮](bold blue)"
EOF

  log "Starship 설정 작성 완료: $STARSHIP_CONFIG"
}

install_tpm() {
  if [[ -d "$TPM_DIR" ]]; then
    log "TPM 이미 설치됨"
    return
  fi

  log "TPM 설치"
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
}

write_tmux_conf() {
  backup_file "$TMUX_CONF"

  cat > "$TMUX_CONF" <<'EOF'
# ~/.tmux.conf

# Prefix를 Ctrl-b에서 Ctrl-a로 변경
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# 기본 설정
set -g mouse on
set -g history-limit 100000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g set-clipboard on
set -g escape-time 10

# terminal color
set -g default-terminal "tmux-256color"
set -as terminal-overrides ",xterm-256color:RGB"

# pane split
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# pane 이동
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# window 이동
bind -n S-Left previous-window
bind -n S-Right next-window

# reload
bind r source-file ~/.tmux.conf \; display-message "tmux.conf reloaded"

# vi mode
setw -g mode-keys vi

# TPM plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'

# tmux-continuum
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'

# TPM bootstrap
run '~/.tmux/plugins/tpm/tpm'
EOF

  log "tmux 설정 작성 완료: $TMUX_CONF"
}

install_tmux_plugins() {
  if [[ -x "${TPM_DIR}/bin/install_plugins" ]]; then
    log "tmux plugins 설치"
    "${TPM_DIR}/bin/install_plugins" || warn "tmux plugin 설치 중 일부 실패 가능. tmux 실행 후 prefix + I로 재시도 가능."
  else
    warn "TPM install_plugins 실행 파일을 찾지 못했습니다."
  fi
}

change_default_shell_to_zsh() {
  local zsh_path
  zsh_path="$(command -v zsh)"

  if [[ "$SHELL" == "$zsh_path" ]]; then
    log "기본 shell이 이미 zsh입니다: $SHELL"
    return
  fi

  if ! grep -Fxq "$zsh_path" /etc/shells; then
    log "/etc/shells에 zsh 등록: $zsh_path"
    echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  fi

  log "기본 shell을 zsh로 변경"
  chsh -s "$zsh_path"
}

write_ghostty_config() {
  local ghostty_dir="${HOME}/Library/Application Support/com.mitchellh.ghostty"
  local ghostty_config="${ghostty_dir}/config"

  mkdir -p "$ghostty_dir"
  backup_file "$ghostty_config"

  cat > "$ghostty_config" <<'EOF'
# Ghostty config

theme = dark:catppuccin-mocha,light:catppuccin-latte
font-size = 14
font-family = "JetBrainsMono Nerd Font"

macos-titlebar-style = tabs
window-padding-x = 8
window-padding-y = 8

shell-integration = zsh
copy-on-select = false
confirm-close-surface = false
EOF

  log "Ghostty 설정 작성 완료: $ghostty_config"
}

install_nerd_font() {
  if brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1; then
    log "JetBrainsMono Nerd Font 이미 설치됨"
  else
    log "JetBrainsMono Nerd Font 설치"
    brew install --cask font-jetbrains-mono-nerd-font
  fi
}

main() {
  require_macos

  log "터미널 환경 부트스트랩 시작"
  log "백업 디렉토리: $BACKUP_DIR"

  install_homebrew_if_needed
  ensure_brew_in_shell
  brew_install_packages
  install_nerd_font

  install_oh_my_zsh
  install_zsh_plugins
  patch_zshrc

  write_starship_config

  install_tpm
  write_tmux_conf
  install_tmux_plugins

  write_ghostty_config
  change_default_shell_to_zsh

  log "설치 완료"
  log "새 Ghostty 창을 열거나 아래 명령 실행:"
  log "source ~/.zshrc"
  log "tmux 실행 후 prefix는 Ctrl-a 입니다."
}

main "$@"
