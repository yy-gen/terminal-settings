# tmux 설정 & 단축키 정리

현재 사용 중인 `~/.tmux.conf`의 복제본이 이 저장소 루트의 [`tmux.conf`](tmux.conf)에 있습니다.
다른 머신에서 그대로 셋팅하려면 아래 [다른 곳에서 셋팅하기](#다른-곳에서-셋팅하기)를 따르면 됩니다.

## Prefix

| 키 | 설명 |
|---|---|
| `Ctrl-a` | Prefix (기본 `Ctrl-b`에서 변경됨) |
| `Ctrl-a` `Ctrl-a` | 실제 `Ctrl-a` 입력을 프로그램에 전달 (send-prefix) |

아래 표에서 `prefix`는 `Ctrl-a`를 의미합니다.

## Pane (분할/이동)

| 키 | 설명 |
|---|---|
| `prefix` `\|` | 세로 분할 (좌우) — 현재 경로 유지 |
| `prefix` `-` | 가로 분할 (상하) — 현재 경로 유지 |
| `prefix` `h` | 왼쪽 pane으로 이동 |
| `prefix` `j` | 아래 pane으로 이동 |
| `prefix` `k` | 위 pane으로 이동 |
| `prefix` `l` | 오른쪽 pane으로 이동 |

## Window (이동)

| 키 | 설명 |
|---|---|
| `Shift-←` | 이전 window (prefix 불필요) |
| `Shift-→` | 다음 window (prefix 불필요) |

## 기타

| 키 | 설명 |
|---|---|
| `prefix` `r` | `~/.tmux.conf` 리로드 |
| `prefix` `I` | TPM 플러그인 설치 (tpm 기본 바인딩) |
| `prefix` `[` | copy mode 진입 — **vi 키 바인딩** (`mode-keys vi`) |

## 기본 동작 설정

| 설정 | 값 |
|---|---|
| 마우스 지원 | on |
| 히스토리 | 100,000 줄 |
| window/pane 시작 번호 | 1 |
| window 번호 자동 재정렬 | on (`renumber-windows`) |
| 시스템 클립보드 연동 | on (`set-clipboard`) |
| ESC 지연 | 10ms |
| 터미널 | `tmux-256color` + TrueColor(RGB) |

## 플러그인 (TPM)

| 플러그인 | 역할 |
|---|---|
| [tpm](https://github.com/tmux-plugins/tpm) | 플러그인 매니저 |
| tmux-sensible | 합리적 기본값 모음 |
| tmux-resurrect | 세션 저장/복원 |
| tmux-continuum | 자동 저장(15분 간격) + 시작 시 자동 복원 (`@continuum-restore on`) |

## 다른 곳에서 셋팅하기

```bash
# 1. tmux 설치 (예: Ubuntu/Mint)
sudo apt install tmux

# 2. 설정 파일 복사
cp tmux.conf ~/.tmux.conf

# 3. TPM(플러그인 매니저) 설치
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# 4. tmux 실행 후 플러그인 설치
tmux
# tmux 안에서: Ctrl-a I  (대문자 I)
```

> 참고: 이 저장소의 `install-terminal-stack.sh` / `install-terminal-stack-mint.sh` 스크립트에도
> 동일한 tmux 설정 작성 및 TPM 설치 과정이 포함되어 있어, 전체 스택을 한 번에 셋팅할 수도 있습니다.
