## 1. 요약

현재 `nvim` 설정 기준 핵심은 **Leader = Space**다.
처음에는 **`Space + e`, `Space + ff`, `Space + fg`, `gd`, `gr`, `Space + tt`** 만 외우면 된다.

---

## 2. 정의

`Leader`는 사용자 단축키의 prefix다.

```text
<leader> = Space
```

예를 들면:

```text
<leader>e   = Space 누르고 e
<leader>ff  = Space 누르고 f 누르고 f
<leader>ca  = Space 누르고 c 누르고 a
```

---

## 3. 필요성

이 단축키 세트는 `nvim`을 다음 흐름으로 쓰기 위한 구성이다.

```text
파일 탐색 → 파일 검색 → 코드 이동 → 수정 → 저장 → 터미널/빌드 확인
```

`tmux + claude + nvim` 조합에서는 보통 이렇게 쓴다.

```text
tmux pane 1: claude
tmux pane 2: nvim
tmux pane 3: mvn test / npm run build
tmux pane 4: git diff / log
```

---

## 4. 미도입 리스크

단축키를 모르면 플러그인을 설치해도 생산성이 거의 안 나온다.

| 문제            | 영향                                      |
| ------------- | --------------------------------------- |
| 파일트리 미사용      | 프로젝트 구조 탐색 느림                           |
| Telescope 미사용 | 파일/문자열 검색을 `find`, `grep`으로 수동 처리       |
| LSP 미사용       | 정의 이동, 참조 검색, rename, code action 활용 못함 |
| Terminal 미사용  | 빌드/테스트를 매번 tmux pane으로 이동               |
| Buffer 미숙     | 열린 파일 간 이동이 느림                          |

---

## 5. 3가지 대안

## 대안 1 — 최소 암기 단축키

처음에는 이것만 쓰면 된다.

| 단축키          | 기능             |
| ------------ | -------------- |
| `Space + e`  | 파일트리 열기/닫기     |
| `Space + ff` | 파일 검색          |
| `Space + fg` | 프로젝트 전체 문자열 검색 |
| `gd`         | 정의로 이동         |
| `gr`         | 참조 검색          |
| `K`          | hover 문서 보기    |
| `Space + w`  | 저장             |
| `Space + q`  | 종료             |
| `Space + tt` | 하단 터미널 열기/닫기   |

### 사용 흐름

```text
Space + e   → 프로젝트 구조 확인
Space + ff  → 파일명으로 이동
Space + fg  → 문자열 검색
gd          → 메서드/클래스 정의 이동
gr          → 참조 검색
Space + w   → 저장
Space + tt  → 터미널에서 테스트/빌드
```

---

## 대안 2 — 전체 단축키 표

## Core

| 단축키         | 기능              |
| ----------- | --------------- |
| `Space + w` | 현재 파일 저장        |
| `Space + q` | 현재 window 종료    |
| `Space + h` | 검색 highlight 제거 |

---

## Window 이동

| 단축키        | 기능             |
| ---------- | -------------- |
| `Ctrl + h` | 왼쪽 window로 이동  |
| `Ctrl + j` | 아래 window로 이동  |
| `Ctrl + k` | 위 window로 이동   |
| `Ctrl + l` | 오른쪽 window로 이동 |

---

## Buffer 이동

| 단축키          | 기능           |
| ------------ | ------------ |
| `Shift + l`  | 다음 buffer    |
| `Shift + h`  | 이전 buffer    |
| `Space + bd` | 현재 buffer 삭제 |

---

## Visual Mode

| 단축키 | 기능              |
| --- | --------------- |
| `<` | 들여쓰기 감소 후 선택 유지 |
| `>` | 들여쓰기 증가 후 선택 유지 |
| `J` | 선택 영역을 아래로 이동   |
| `K` | 선택 영역을 위로 이동    |

---

## File Tree — `nvim-tree`

| 단축키         | 기능          |
| ----------- | ----------- |
| `Space + e` | 파일트리 toggle |
| `Space + o` | 파일트리 focus  |

### 파일트리 내부 기본 키

| 단축키     | 기능         |
| ------- | ---------- |
| `Enter` | 파일 열기      |
| `a`     | 파일/디렉토리 생성 |
| `d`     | 삭제         |
| `r`     | 이름 변경      |
| `x`     | 잘라내기       |
| `c`     | 복사         |
| `p`     | 붙여넣기       |
| `R`     | 새로고침       |
| `?`     | 도움말        |

---

## Telescope 검색

| 단축키          | 기능             |
| ------------ | -------------- |
| `Space + ff` | 파일 검색          |
| `Space + fg` | 프로젝트 전체 문자열 검색 |
| `Space + fb` | 열린 buffer 검색   |
| `Space + fh` | help tag 검색    |
| `Space + fr` | 최근 파일 검색       |

### Telescope 창 내부

| 단축키        | 기능    |
| ---------- | ----- |
| `Ctrl + j` | 아래 항목 |
| `Ctrl + k` | 위 항목  |
| `Enter`    | 선택    |
| `Esc`      | 닫기    |

---

## Terminal — `toggleterm`

| 단축키          | 기능                |
| ------------ | ----------------- |
| `Space + tt` | terminal toggle   |
| `Space + tf` | floating terminal |
| `Ctrl + \`   | terminal toggle   |

실사용은 `Space + tt`가 제일 안정적이다.

---

## LSP

LSP가 attach된 파일에서 동작한다.

| 단축키          | 기능                  |
| ------------ | ------------------- |
| `gd`         | definition 이동       |
| `gD`         | declaration 이동      |
| `gi`         | implementation 이동   |
| `gr`         | references 검색       |
| `K`          | hover documentation |
| `Space + rn` | symbol rename       |
| `Space + ca` | code action         |
| `Space + cf` | format code         |
| `[d`         | 이전 diagnostic       |
| `]d`         | 다음 diagnostic       |
| `Space + dd` | 현재 라인 diagnostic 보기 |

---

## Comment

| 단축키   | 기능              |
| ----- | --------------- |
| `gcc` | 현재 라인 주석 toggle |
| `gc`  | 선택 영역 주석 toggle |

사용 예:

```text
Normal mode: gcc
Visual mode: 영역 선택 후 gc
```

---

## 대안 3 — 터미널에서 볼 Cheat Sheet 파일 생성

아래 명령으로 `~/nvim-keymaps.txt` 파일을 만들어두면 된다.

```bash
cat > ~/nvim-keymaps.txt <<'EOF'
# Neovim Keymaps

Leader = Space

[Core]
Space+w   Save file
Space+q   Quit
Space+h   Clear search highlight

[Window]
Ctrl+h    Move left window
Ctrl+j    Move lower window
Ctrl+k    Move upper window
Ctrl+l    Move right window

[Buffer]
Shift+l   Next buffer
Shift+h   Previous buffer
Space+bd  Delete buffer

[Visual Mode]
<         Decrease indent and keep selection
>         Increase indent and keep selection
J         Move selected lines down
K         Move selected lines up

[File Tree]
Space+e   Toggle file tree
Space+o   Focus file tree

[NvimTree 내부]
Enter     Open file
a         Create file/directory
d         Delete
r         Rename
x         Cut
c         Copy
p         Paste
R         Refresh
?         Help

[Telescope]
Space+ff  Find files
Space+fg  Live grep
Space+fb  Buffers
Space+fh  Help tags
Space+fr  Recent files

[Telescope 내부]
Ctrl+j    Move down
Ctrl+k    Move up
Enter     Select
Esc       Close

[Terminal]
Space+tt  Toggle terminal
Space+tf  Floating terminal
Ctrl+\    Toggle terminal

[LSP]
gd        Go to definition
gD        Go to declaration
gi        Go to implementation
gr        Find references
K         Hover documentation
Space+rn  Rename symbol
Space+ca  Code action
Space+cf  Format code
[d        Previous diagnostic
]d        Next diagnostic
Space+dd  Line diagnostics

[Comment]
gcc       Toggle line comment
gc        Toggle selected comment
EOF
```

확인:

```bash
cat ~/nvim-keymaps.txt
```

---

## 6. 단점·부작용

### 1) `Ctrl + h/j/k/l`은 tmux와 구분 필요

현재 구조에서는 이렇게 구분하면 된다.

```text
nvim 내부 window 이동 : Ctrl + h/j/k/l
tmux pane 이동        : Ctrl-a + h/j/k/l
```

즉:

```text
Ctrl-h      nvim 왼쪽 window
Ctrl-a h    tmux 왼쪽 pane
```

---

### 2) `K`는 mode에 따라 다르게 동작

Normal mode에서 LSP attach 상태:

```text
K = hover documentation
```

Visual mode:

```text
K = 선택 영역 위로 이동
```

---

### 3) Java LSP는 별도 구성 필요

현재 기본 LSP는 주로 다음 쪽이다.

```text
lua
typescript
html
css
json
yaml
bash
```

Spring Boot/eGovFrame Java 개발까지 제대로 쓰려면 `jdtls` 또는 `nvim-jdtls`를 추가해야 한다.

---

## 7. 검증

## WhichKey 확인

Neovim에서 `Space`를 누르고 잠깐 기다리면 사용 가능한 단축키가 뜬다.

또는 명령어:

```vim
:WhichKey
```

---

## 파일트리 확인

```text
Space + e
```

기대 결과:

```text
좌측 파일트리 열림
```

---

## 파일 검색 확인

```text
Space + ff
```

기대 결과:

```text
Telescope 파일 검색 팝업
```

---

## 문자열 검색 확인

```text
Space + fg
```

기대 결과:

```text
Telescope live grep 팝업
```

---

## LSP 확인

```vim
:LspInfo
```

LSP attach된 파일에서 다음 키가 동작해야 한다.

```text
gd
gr
K
Space + ca
Space + cf
```

---

## 최종 암기 세트

이 9개만 먼저 외우면 된다.

```text
Space + e   파일트리
Space + ff  파일 검색
Space + fg  전체 grep
Space + fb  열린 buffer
gd          정의 이동
gr          참조 검색
K           문서 보기
Space + w   저장
Space + tt  터미널
```

