#!/usr/bin/env zsh
#
# find + grep 콤보 셋업 스크립트
#
# 사용법:
#   ./find-grep-setup.zsh                 # 한 번만 실행: 홈에 설치 + .zshrc 등록
#   source ./find-grep-setup.zsh          # 현재 셸에서만 임시 사용 (설치 X)
#
# 설치 후 사용 가능한 명령:
#   f, fdir, fbig, fnew           — find 관련
#   gr, grcase                    — 재귀 grep
#   ftext, fcode, fmatch          — find+grep 본편
#   finame                        — 파일명 + 내용 동시 필터

# ============================================================
# ALIAS & FUNCTION 정의
# (install 모드 시 ~/.config/zsh/find-grep-aliases.zsh 로 복사되어 .zshrc 에서 source 됨)
# ============================================================

# ── find: 파일/디렉토리 메타데이터 ────────────────────────────

# f <pattern>        : 이름으로 파일 찾기 (대소문자 무시, 현재 디렉토리)
alias f='find . -type f -iname'

# fdir <pattern>     : 디렉토리 찾기
alias fdir='find . -type d -iname'

# fbig               : 현재 디렉토리에서 가장 큰 파일 20개 (BSD/macOS find 호환)
alias fbig='find . -type f -printf "%s %p\n" 2>/dev/null | sort -rn | head -n 20'

# fnew               : 최근 60분 이내 수정된 파일 (숨김 경로 제외)
alias fnew='find . -type f -mmin -60 -not -path "*/\.*" 2>/dev/null'

# ── grep: 파일 내용 (재귀 + 라인번호) ────────────────────────

alias gr='grep -rniI --color=auto --exclude-dir=.git'        # 대소문자 무시
alias grcase='grep -rnI --color=auto --exclude-dir=.git'      # 대소문자 구분

# ── find + grep 메인 콤보 ─────────────────────────────────────

# ftext <pattern> [path]
#   일반 텍스트/문서 검색. VCS/빌드 산출물/락파일 자동 제외.
ftext() {
  grep -rniI --color=auto "$@" \
    --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=vendor \
    --exclude-dir=target --exclude-dir=build --exclude-dir=dist \
    --exclude-dir=.venv --exclude-dir=.idea --exclude-dir=.next \
    --exclude-dir=.cache --exclude-dir=Pods --exclude-dir=DerivedData \
    --exclude-dir=.gradle --exclude-dir=out \
    --exclude='*.min.*' --exclude='*.lock' \
    --exclude='package-lock.json' --exclude='yarn.lock' \
    --exclude='Cargo.lock' --exclude='go.sum' --exclude='pnpm-lock.yaml'
}

# fcode <pattern> [path]
#   소스 코드만 검색 (확장자 화이트리스트 + 노이즈 디렉토리 제외).
fcode() {
  grep -rniI --color=auto "$@" \
    --include='*.js' --include='*.jsx' --include='*.ts' --include='*.tsx' \
    --include='*.mjs' --include='*.cjs' --include='*.py' --include='*.java' \
    --include='*.kt' --include='*.go' --include='*.rs' --include='*.c' \
    --include='*.cc' --include='*.cpp' --include='*.h' --include='*.hpp' \
    --include='*.rb' --include='*.php' --include='*.swift' \
    --include='*.sh' --include='*.zsh' --include='*.sql' \
    --include='*.html' --include='*.css' --include='*.scss' \
    --include='*.vue' --include='*.svelte' --include='*.dart' \
    --include='*.ex' --include='*.exs' \
    --exclude-dir=.git --exclude-dir=node_modules \
    --exclude-dir=venv --exclude-dir=.venv \
    --exclude-dir=target --exclude-dir=build --exclude-dir=dist \
    --exclude-dir=Pods --exclude-dir=.idea --exclude-dir=.next \
    --exclude-dir=.gradle --exclude-dir=out
}

# fmatch <pattern> [path]
#   내용이 매칭되는 파일 *경로만* (라인/문맥 없음).
fmatch() {
  grep -rlniI --color=never "$@" \
    --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=vendor \
    --exclude-dir=target --exclude-dir=build --exclude-dir=dist \
    --exclude-dir=.venv --exclude-dir=Pods --exclude-dir=DerivedData
}

# ── glob → regex (단순 변환: * → .*, ? → .) ──────────────────

glob_to_regex() {
  local p=$1
  p=${p//\*/.*}
  p=${p//\?/.}
  printf '%s\n' "$p"
}

# ── finame: 이름 + 내용 동시 필터 ─────────────────────────────

# finame <name-glob> <content-glob> [path]
#   두 인자 모두 glob 패턴 — *Controller, *Service*, ? (한 글자) 등.
#   예) finame '*Controller.java' 'login' src/
finame() {
  local name="${1:-}" text="${2:-}" dir="${3:-.}"
  [ -z "$name" ] || [ -z "$text" ] && {
    echo "usage: finame <name-glob> <content-glob> [path]"; return 1
  }
  local text_re; text_re=$(glob_to_regex "$text")
  find "$dir" -type f -iname "$name" -not -path '*/\.*' 2>/dev/null \
    | xargs grep -niI --color=auto -- "$text_re" 2>/dev/null
}

# ============================================================
# >>> INSTALL_LOGIC_BEGIN <<<  -- sed 가 이 줄부터 끝까지 잘라냄
# ============================================================

# ZSH_EVAL_CONTEXT 에 'file' 이 없으면 직접 실행(=install 모드).
# source 로 실행 시에는 'file:...' 가 들어가므로 무조건 skip.
if [[ "$ZSH_EVAL_CONTEXT" != *file* ]]; then
  INSTALL_DIR="${HOME}/.config/zsh"
  INSTALL_FILE="${INSTALL_DIR}/find-grep-aliases.zsh"
  ZSHRC="${HOME}/.zshrc"
  MARKER_BEGIN='# >>> find + grep 콤보 (auto-installed by find-grep-setup.zsh) >>>'
  MARKER_END='# <<< find + grep 콤보 <<<'

  # 사전 점검
  [[ -z "$HOME" ]] && { echo "ERR: \$HOME 미설정" >&2; exit 1; }
  mkdir -p "$INSTALL_DIR" 2>/dev/null || {
    echo "ERR: 디렉토리 생성 실패: $INSTALL_DIR" >&2; exit 1
  }
  [[ -f "$ZSHRC" ]] || touch "$ZSHRC"

  # 1) 이 스크립트의 alias/function 정의 부분만 INSTALL_FILE 로 추출.
  #    INSTALL_LOGIC_BEGIN marker 부터 끝까지 제거 → 재귀 install 방지.
  sed -n '/^# >>> INSTALL_LOGIC_BEGIN <<</,$d;p' "$0" > "$INSTALL_FILE" \
    || { echo "ERR: $INSTALL_FILE 생성 실패" >&2; exit 1; }
  chmod 644 "$INSTALL_FILE"

  # 2) .zshrc 에 source 라인 추가 (마커 블록 안으로 — 이미 있으면 건너뜀)
  if grep -qF "source \"$INSTALL_FILE\"" "$ZSHRC" 2>/dev/null; then
    echo "· $ZSHRC 에 이미 source 라인 존재 (skip)"
  else
    # 기존 마커 블록이 있으면 제거 (재설치 idempotent)
    if grep -qF "$MARKER_BEGIN" "$ZSHRC" 2>/dev/null; then
      awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
        index($0, b) { skip=1; next }
        skip && index($0, e) { skip=0; next }
        !skip
      ' "$ZSHRC" > "${ZSHRC}.tmp" && mv "${ZSHRC}.tmp" "$ZSHRC"
      echo "✓ 기존 marker 블록 제거"
    fi

    # 새 마커 + source 라인 추가
    {
      echo ""
      echo "$MARKER_BEGIN"
      echo "[[ -f \"$INSTALL_FILE\" ]] && source \"$INSTALL_FILE\""
      echo "$MARKER_END"
    } >> "$ZSHRC"
    echo "✓ $ZSHRC 에 source 라인 추가됨"
  fi

  echo ""
  echo "===================================================="
  echo " ✓ 설치 완료"
  echo "   파일: $INSTALL_FILE"
  echo ""
  echo " · 새 셸: 모든 alias/함수 자동 사용 가능"
  echo " · 현재 셸: source ~/.zshrc  입력하면 즉시 사용 가능"
  echo "===================================================="
fi
