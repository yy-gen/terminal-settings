#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Linux Mint Dev Terminal Bootstrap
# Stack: apt + Oh My Zsh + tmux + Starship + Ghostty
# Author: local bootstrap (macOS install-terminal-stack.sh 포팅)
# ============================================================

readonly NOW="$(date +%Y%m%d_%H%M%S)"
readonly BACKUP_DIR="${HOME}/.terminal-bootstrap-backup/${NOW}"
readonly ZSHRC="${HOME}/.zshrc"
readonly TMUX_CONF="${HOME}/.tmux.conf"
readonly STARSHIP_CONFIG_DIR="${HOME}/.config"
readonly STARSHIP_CONFIG="${STARSHIP_CONFIG_DIR}/starship.toml"
readonly TPM_DIR="${HOME}/.tmux/plugins/tpm"
readonly FONT_DIR="${HOME}/.local/share/fonts/JetBrainsMonoNerdFont"

log() {
  printf "\033[1;32m[INFO]\033[0m %s\n" "$*"
}

warn() {
  printf "\033[1;33m[WARN]\033[0m %s\n" "$*"
}

err() {
  printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2
}

require_mint() {
  if [[ ! -f /etc/os-release ]]; then
    err "/etc/os-release를 찾을 수 없습니다. 이 스크립트는 Linux Mint 전용입니다."
    exit 1
  fi

  # shellcheck disable=SC1091
  source /etc/os-release

  if [[ "${ID:-}" != "linuxmint" && "${ID_LIKE:-}" != *ubuntu* ]]; then
    err "이 스크립트는 Linux Mint(우분투 계열) 전용입니다. 감지된 ID: ${ID:-unknown}"
    exit 1
  fi
}

# Mint의 우분투 베이스 버전 (Ghostty deb 선택에 사용)
ubuntu_base_version() {
  case "${UBUNTU_CODENAME:-}" in
    jammy) echo "22.04" ;;
    noble) echo "24.04" ;;
    *) echo "" ;;
  esac
}

backup_file() {
  local file="$1"

  if [[ -f "$file" ]]; then
    mkdir -p "$BACKUP_DIR"
    cp "$file" "${BACKUP_DIR}/$(basename "$file")"
    log "백업 완료: $file -> ${BACKUP_DIR}/$(basename "$file")"
  fi
}

apt_install_packages() {
  log "apt update 실행"
  sudo apt-get update

  local packages=(
    git
    zsh
    tmux
    fzf
    zoxide
    curl
    wget
    unzip
    gpg
    fontconfig
  )

  local to_install=()
  for pkg in "${packages[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      log "이미 설치됨: $pkg"
    else
      to_install+=("$pkg")
    fi
  done

  if ((${#to_install[@]} > 0)); then
    log "설치 중: ${to_install[*]}"
    sudo apt-get install -y "${to_install[@]}"
  fi
}

install_eza() {
  if command -v eza >/dev/null 2>&1; then
    log "eza 이미 설치됨"
    return
  fi

  # Mint 22(noble)부터는 apt 기본 저장소에 있고, Mint 21(jammy)은 gierens 저장소가 필요하다.
  if apt-cache show eza >/dev/null 2>&1; then
    log "eza 설치 (apt)"
    sudo apt-get install -y eza
    return
  fi

  log "eza 공식 deb 저장소(gierens.de) 등록 후 설치"
  sudo mkdir -p /etc/apt/keyrings
  wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
    | sudo gpg --dearmor --yes -o /etc/apt/keyrings/gierens.gpg
  echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y eza
}

install_starship() {
  if command -v starship >/dev/null 2>&1; then
    log "Starship 이미 설치됨: $(starship --version | head -n 1)"
    return
  fi

  # starship은 apt에 없어서 공식 설치 스크립트를 사용한다 (/usr/local/bin에 설치).
  log "Starship 설치 시작"
  curl -sS https://starship.rs/install.sh | sh -s -- -y
}

install_ghostty() {
  if command -v ghostty >/dev/null 2>&1; then
    log "Ghostty 이미 설치됨"
    return
  fi

  local ubuntu_ver
  ubuntu_ver="$(ubuntu_base_version)"

  if [[ -z "$ubuntu_ver" ]]; then
    warn "우분투 베이스 버전을 감지하지 못해 Ghostty 설치를 건너뜁니다."
    warn "수동 설치: https://github.com/mkasberg/ghostty-ubuntu/releases"
    return
  fi

  # Ghostty는 공식 리눅스 패키지가 없어서 ghostty-ubuntu 커뮤니티 빌드 deb를 사용한다.
  log "Ghostty deb 다운로드 (Ubuntu ${ubuntu_ver} 베이스)"

  local deb_url
  deb_url="$(curl -fsSL https://api.github.com/repos/mkasberg/ghostty-ubuntu/releases/latest \
    | grep -oE '"browser_download_url": *"[^"]+"' \
    | grep -oE 'https://[^"]+' \
    | grep "amd64_${ubuntu_ver}.deb" \
    | head -n 1 || true)"

  if [[ -z "$deb_url" ]]; then
    warn "Ghostty deb 다운로드 URL을 찾지 못해 설치를 건너뜁니다."
    warn "수동 설치: https://github.com/mkasberg/ghostty-ubuntu/releases"
    return
  fi

  local tmp_deb
  tmp_deb="$(mktemp --suffix=.deb)"
  curl -fsSL -o "$tmp_deb" "$deb_url"
  sudo apt-get install -y "$tmp_deb"
  rm -f "$tmp_deb"
}

install_nerd_font() {
  if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
    log "JetBrainsMono Nerd Font 이미 설치됨"
    return
  fi

  log "JetBrainsMono Nerd Font 설치"

  local tmp_zip
  tmp_zip="$(mktemp --suffix=.zip)"
  curl -fsSL -o "$tmp_zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"

  mkdir -p "$FONT_DIR"
  unzip -o -q "$tmp_zip" -d "$FONT_DIR"
  rm -f "$tmp_zip"

  fc-cache -f "$FONT_DIR"
  log "폰트 캐시 갱신 완료"
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

  # Oh My Zsh 기본 로딩 블록 (macos 플러그인은 리눅스에서 제외)
  if ! grep -Fq "# >>> oh-my-zsh bootstrap >>>" "$ZSHRC"; then
    cat >> "$ZSHRC" <<'EOF'

# >>> oh-my-zsh bootstrap >>>
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""

plugins=(
  git
  docker
  npm
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

# fzf 0.48+ 는 --zsh 지원, 우분투 계열 apt 버전(구버전)은 examples 스크립트 사용
if command -v fzf >/dev/null 2>&1; then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
  else
    [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [[ -f /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
  fi
fi

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
symbol = " "
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
format = '[$symbol$context( \($namespace\))]($style) '
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
  # 리눅스에서 Ghostty 설정 경로는 ~/.config/ghostty/config
  local ghostty_dir="${HOME}/.config/ghostty"
  local ghostty_config="${ghostty_dir}/config"

  mkdir -p "$ghostty_dir"
  backup_file "$ghostty_config"

  cat > "$ghostty_config" <<'EOF'
# Ghostty config

theme = dark:catppuccin-mocha,light:catppuccin-latte
font-size = 14
font-family = "JetBrainsMono Nerd Font"

window-padding-x = 8
window-padding-y = 8

shell-integration = zsh
copy-on-select = false
confirm-close-surface = false
EOF

  log "Ghostty 설정 작성 완료: $ghostty_config"
}

main() {
  require_mint

  log "터미널 환경 부트스트랩 시작 (Linux Mint)"
  log "백업 디렉토리: $BACKUP_DIR"

  # sudo 세션 미리 확보
  sudo -v

  apt_install_packages
  install_eza
  install_starship
  install_ghostty
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
  log "로그아웃/로그인 후 기본 shell(zsh)이 적용됩니다. 즉시 적용하려면:"
  log "zsh 실행 후 source ~/.zshrc"
  log "tmux 실행 후 prefix는 Ctrl-a 입니다."
}

main "$@"
