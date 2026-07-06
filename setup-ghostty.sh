#!/usr/bin/env bash
# Ghostty 설정 자동 셋업 스크립트 (macOS / Linux)
# 사용법: bash setup-ghostty.sh
set -euo pipefail

# OS별 설정 파일 경로 결정
case "$(uname -s)" in
  Darwin) CONFIG_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty" ;;
  Linux)  CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty" ;;
  *) echo "지원하지 않는 OS: $(uname -s)" >&2; exit 1 ;;
esac

CONFIG_FILE="$CONFIG_DIR/config"
mkdir -p "$CONFIG_DIR"

# 기존 설정이 있으면 백업
if [ -f "$CONFIG_FILE" ]; then
  BACKUP="$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
  cp "$CONFIG_FILE" "$BACKUP"
  echo "기존 설정 백업: $BACKUP"
fi

cat > "$CONFIG_FILE" <<'EOF'
# Ghostty config

theme = Dracula
font-size = 14
font-family = "JetBrainsMono Nerd Font"

macos-titlebar-style = tabs
window-padding-x = 8
window-padding-y = 8

shell-integration = zsh
copy-on-select = false
confirm-close-surface = false

# Claude Code: Shift+Enter로 줄바꿈 (tmux 통과용)
keybind = shift+enter=text:\x1b\r
EOF

echo "Ghostty 설정 작성 완료: $CONFIG_FILE"

# 폰트 확인 (없으면 안내만)
if command -v fc-list >/dev/null 2>&1; then
  if ! fc-list | grep -qi "JetBrainsMono Nerd Font"; then
    echo "주의: JetBrainsMono Nerd Font가 설치되어 있지 않습니다."
    echo "  macOS: brew install --cask font-jetbrains-mono-nerd-font"
    echo "  Linux: https://www.nerdfonts.com/font-downloads 에서 JetBrainsMono 설치"
  fi
fi

echo "완료. Ghostty를 재시작하거나 설정을 리로드하세요."
