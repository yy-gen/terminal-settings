#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Linux Mint Neovim Bootstrap (macOS install-nvim-dev.sh 포팅)
# Stack:
#   Neovim + lazy.nvim + nvim-tree + telescope + treesitter
#   lspconfig + mason + which-key + lualine + toggleterm
# ============================================================

readonly NOW="$(date +%Y%m%d_%H%M%S)"
readonly NVIM_CONFIG_DIR="${HOME}/.config/nvim"
readonly NVIM_DATA_DIR="${HOME}/.local/share/nvim"
readonly NVIM_STATE_DIR="${HOME}/.local/state/nvim"
readonly NVIM_CACHE_DIR="${HOME}/.cache/nvim"
readonly BACKUP_DIR="${HOME}/.nvim-bootstrap-backup/${NOW}"

# 설정에서 vim.lsp.config / vim.diagnostic.jump 를 쓰므로 0.11 이상 필요
readonly NVIM_MIN_VERSION="0.11"

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

  if [[ "$(uname -m)" != "x86_64" ]]; then
    err "이 스크립트는 x86_64 전용입니다. 감지된 아키텍처: $(uname -m)"
    exit 1
  fi
}

backup_path_if_exists() {
  local path="$1"
  # 백업 대상들의 basename이 전부 nvim이라 겹치므로, 고유한 이름을 두 번째 인자로 받는다.
  local name="$2"

  if [[ -e "$path" ]]; then
    mkdir -p "$BACKUP_DIR"
    mv "$path" "${BACKUP_DIR}/${name}"
    log "Backup: $path -> ${BACKUP_DIR}/${name}"
  fi
}

install_packages() {
  log "apt update"
  sudo apt-get update

  # neovim/tree-sitter-cli/lazygit은 apt 버전이 너무 오래되어 별도 설치한다.
  local packages=(
    git
    curl
    unzip
    build-essential
    ripgrep
    fd-find
    fzf
    luarocks
    nodejs
    npm
    python3
    python3-pip
    python3-venv
    xclip
    wl-clipboard
  )

  local to_install=()
  for pkg in "${packages[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      log "Already installed: $pkg"
    else
      to_install+=("$pkg")
    fi
  done

  if ((${#to_install[@]} > 0)); then
    log "Installing: ${to_install[*]}"
    sudo apt-get install -y "${to_install[@]}"
  fi

  # 우분투 계열은 fd 바이너리 이름이 fdfind라서 fd로 심볼릭 링크를 만든다.
  if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
    log "fd -> fdfind 심볼릭 링크 생성"
    sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
  fi
}

nvim_version_ok() {
  command -v nvim >/dev/null 2>&1 || return 1

  local current
  current="$(nvim --version | head -n 1 | grep -oE '[0-9]+\.[0-9]+' | head -n 1)"
  [[ -n "$current" ]] || return 1

  # sort -V로 최소 버전 충족 여부 확인
  [[ "$(printf '%s\n%s\n' "$NVIM_MIN_VERSION" "$current" | sort -V | head -n 1)" == "$NVIM_MIN_VERSION" ]]
}

install_neovim() {
  if nvim_version_ok; then
    log "Neovim already installed: $(nvim --version | head -n 1)"
    return
  fi

  # apt의 neovim은 구버전(0.9.x)이라 공식 릴리스 tarball을 /opt에 설치한다.
  log "Installing latest stable Neovim to /opt/nvim-linux-x86_64"

  local tmp_tar
  tmp_tar="$(mktemp --suffix=.tar.gz)"
  curl -fsSL -o "$tmp_tar" \
    "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"

  sudo rm -rf /opt/nvim-linux-x86_64
  sudo tar -C /opt -xzf "$tmp_tar"
  sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
  rm -f "$tmp_tar"

  if ! nvim_version_ok; then
    err "Neovim ${NVIM_MIN_VERSION}+ 설치에 실패했습니다."
    exit 1
  fi

  log "Installed: $(nvim --version | head -n 1)"
}

install_tree_sitter_cli() {
  if command -v tree-sitter >/dev/null 2>&1; then
    log "tree-sitter CLI already installed"
    return
  fi

  # apt에 tree-sitter-cli 패키지가 없어서 npm 글로벌로 설치한다.
  log "Installing tree-sitter CLI via npm"
  sudo npm install -g tree-sitter-cli
}

install_lazygit() {
  if command -v lazygit >/dev/null 2>&1; then
    log "lazygit already installed"
    return
  fi

  log "Installing lazygit from GitHub releases"

  local version
  version="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
    | grep -oE '"tag_name": *"v[^"]+"' \
    | grep -oE '[0-9][0-9.]*' \
    | head -n 1 || true)"

  if [[ -z "$version" ]]; then
    warn "lazygit 최신 버전을 확인하지 못해 설치를 건너뜁니다."
    return
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  curl -fsSL -o "${tmp_dir}/lazygit.tar.gz" \
    "https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_x86_64.tar.gz"
  tar -C "$tmp_dir" -xzf "${tmp_dir}/lazygit.tar.gz" lazygit
  sudo install "${tmp_dir}/lazygit" -D -t /usr/local/bin/
  rm -rf "$tmp_dir"
}

backup_old_nvim() {
  log "Backing up existing Neovim config/data if present"

  backup_path_if_exists "$NVIM_CONFIG_DIR" "config-nvim"

  # plugin/data/cache도 같이 백업해야 lazy lock 꼬임을 피할 수 있다.
  backup_path_if_exists "$NVIM_DATA_DIR" "share-nvim"
  backup_path_if_exists "$NVIM_STATE_DIR" "state-nvim"
  backup_path_if_exists "$NVIM_CACHE_DIR" "cache-nvim"
}

write_nvim_config() {
  log "Writing Neovim config"

  mkdir -p "$NVIM_CONFIG_DIR/lua/core"
  mkdir -p "$NVIM_CONFIG_DIR/lua/plugins"

  cat > "$NVIM_CONFIG_DIR/init.lua" <<'LUA'
require("core.options")
require("core.keymaps")
require("core.lazy")
LUA

  cat > "$NVIM_CONFIG_DIR/lua/core/options.lua" <<'LUA'
-- ============================================================
-- Core Options
-- ============================================================

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.termguicolors = true
opt.signcolumn = "yes"

opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true

opt.wrap = false
opt.scrolloff = 8
opt.sidescrolloff = 8

opt.ignorecase = true
opt.smartcase = true

opt.splitbelow = true
opt.splitright = true

-- 리눅스에서는 xclip(X11)/wl-clipboard(Wayland)가 설치되어 있어야 동작한다.
opt.clipboard = "unnamedplus"
opt.mouse = "a"

opt.undofile = true
opt.swapfile = false
opt.backup = false

opt.updatetime = 250
opt.timeoutlen = 400

-- 터미널/tmux 조합에서 color 문제를 줄이기 위한 기본값
opt.background = "dark"

-- 파일 저장 시 마지막 위치 복원
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})
LUA

  cat > "$NVIM_CONFIG_DIR/lua/core/keymaps.lua" <<'LUA'
-- ============================================================
-- Keymaps
-- Leader: Space
-- ============================================================

local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

-- 기본
keymap("n", "<leader>w", "<cmd>w<cr>", vim.tbl_extend("force", opts, { desc = "Save file" }))
keymap("n", "<leader>q", "<cmd>q<cr>", vim.tbl_extend("force", opts, { desc = "Quit" }))
keymap("n", "<leader>h", "<cmd>nohlsearch<cr>", vim.tbl_extend("force", opts, { desc = "Clear search highlight" }))

-- window 이동
keymap("n", "<C-h>", "<C-w>h", vim.tbl_extend("force", opts, { desc = "Move left window" }))
keymap("n", "<C-j>", "<C-w>j", vim.tbl_extend("force", opts, { desc = "Move lower window" }))
keymap("n", "<C-k>", "<C-w>k", vim.tbl_extend("force", opts, { desc = "Move upper window" }))
keymap("n", "<C-l>", "<C-w>l", vim.tbl_extend("force", opts, { desc = "Move right window" }))

-- buffer
keymap("n", "<S-l>", "<cmd>bnext<cr>", vim.tbl_extend("force", opts, { desc = "Next buffer" }))
keymap("n", "<S-h>", "<cmd>bprevious<cr>", vim.tbl_extend("force", opts, { desc = "Previous buffer" }))
keymap("n", "<leader>bd", "<cmd>bdelete<cr>", vim.tbl_extend("force", opts, { desc = "Delete buffer" }))

-- visual mode indent 후 선택 유지
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

-- 줄 이동
keymap("v", "J", ":m '>+1<CR>gv=gv", opts)
keymap("v", "K", ":m '<-2<CR>gv=gv", opts)
LUA

  cat > "$NVIM_CONFIG_DIR/lua/core/lazy.lua" <<'LUA'
-- ============================================================
-- lazy.nvim bootstrap
-- ============================================================

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins", {
  defaults = {
    lazy = false,
  },
  install = {
    colorscheme = { "tokyonight" },
  },
  checker = {
    enabled = true,
    notify = false,
  },
  change_detection = {
    notify = false,
  },
})
LUA

  cat > "$NVIM_CONFIG_DIR/lua/plugins/init.lua" <<'LUA'
return {
  -- Theme
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("tokyonight-night")
    end,
  },

  -- Icons
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
  },

  -- Status line
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          theme = "tokyonight",
          globalstatus = true,
        },
      })
    end,
  },

  -- Keymap helper
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      require("which-key").setup({})
    end,
  },

  -- File tree
  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>e", "<cmd>NvimTreeToggle<cr>", desc = "Toggle file tree" },
      { "<leader>o", "<cmd>NvimTreeFocus<cr>", desc = "Focus file tree" },
    },
    config = function()
      -- netrw와 충돌 방지
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1

      require("nvim-tree").setup({
        sort = {
          sorter = "case_sensitive",
        },
        view = {
          width = 34,
          side = "left",
        },
        renderer = {
          group_empty = true,
          icons = {
            show = {
              file = true,
              folder = true,
              folder_arrow = true,
              git = true,
            },
          },
        },
        filters = {
          dotfiles = false,
        },
        git = {
          enable = true,
          ignore = false,
        },
        actions = {
          open_file = {
            quit_on_open = false,
            resize_window = true,
          },
        },
      })
    end,
  },

  -- Fuzzy finder
  {
    "nvim-telescope/telescope.nvim",
    branch = "master",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Find buffers" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help tags" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent files" },
    },
    config = function()
      require("telescope").setup({
        defaults = {
          prompt_prefix = "  ",
          selection_caret = "❯ ",
          path_display = { "truncate" },
          file_ignore_patterns = {
            "node_modules",
            ".git/",
            "target/",
            "dist/",
            "build/",
          },
        },
        pickers = {
          find_files = {
            hidden = true,
          },
        },
      })
    end,
  },

  -- Syntax parser
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local parsers = {
        "lua",
        "vim",
        "vimdoc",
        "bash",
        "json",
        "yaml",
        "xml",
        "html",
        "css",
        "javascript",
        "typescript",
        "java",
        "sql",
        "markdown",
        "markdown_inline",
      }

      -- 미설치 파서만 비동기로 설치한다 (이미 있으면 no-op).
      -- headless(설치 스크립트)에서는 스크립트의 명시적 설치 단계와
      -- 경쟁하지 않도록, 실제 UI가 붙은 뒤에만 실행한다.
      vim.api.nvim_create_autocmd("UIEnter", {
        once = true,
        callback = function()
          require("nvim-treesitter").install(parsers)
        end,
      })

      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
          if not lang or not vim.tbl_contains(parsers, lang) then
            return
          end
          -- 파서 설치가 아직 안 끝났으면 조용히 넘어간다
          if pcall(vim.treesitter.start, args.buf, lang) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },

  -- Auto pairs
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = true,
  },

  -- Comments
  {
    "numToStr/Comment.nvim",
    keys = {
      { "gcc", mode = "n", desc = "Toggle line comment" },
      { "gc", mode = { "n", "v" }, desc = "Toggle comment" },
    },
    config = true,
  },

  -- Terminal
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
      { "<leader>tt", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
      { "<leader>tf", "<cmd>ToggleTerm direction=float<cr>", desc = "Floating terminal" },
    },
    config = function()
      require("toggleterm").setup({
        size = 15,
        open_mapping = [[<c-\>]],
        direction = "horizontal",
        shade_terminals = true,
      })
    end,
  },

  -- Git signs
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("gitsigns").setup({
        signs = {
          add = { text = "+" },
          change = { text = "~" },
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
        },
      })
    end,
  },

  -- LSP installer
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    config = function()
      require("mason").setup()
    end,
  },

  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
      "williamboman/mason.nvim",
    },
  },

  -- LSP config
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls",
          "ts_ls",
          "html",
          "cssls",
          "jsonls",
          "yamlls",
          "bashls",
        },
        automatic_enable = true,
      })

      -- Lua LSP: Neovim runtime 인식
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = {
              globals = { "vim" },
            },
            workspace = {
              checkThirdParty = false,
            },
            telemetry = {
              enable = false,
            },
          },
        },
      })

      -- Java는 jdtls가 별도 workspace/runtime 설정이 많아서 자동 강제 설정하지 않는다.
      -- 필요 시 nvim-jdtls를 별도 구성하는 것을 권장.

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(event)
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, {
              buffer = event.buf,
              noremap = true,
              silent = true,
              desc = desc,
            })
          end

          map("n", "gd", vim.lsp.buf.definition, "Go to definition")
          map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
          map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
          map("n", "gr", vim.lsp.buf.references, "Find references")
          map("n", "K", vim.lsp.buf.hover, "Hover documentation")
          map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
          map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("n", "<leader>cf", function()
            vim.lsp.buf.format({ async = true })
          end, "Format code")
          map("n", "[d", function()
            vim.diagnostic.jump({ count = -1, float = true })
          end, "Previous diagnostic")
          map("n", "]d", function()
            vim.diagnostic.jump({ count = 1, float = true })
          end, "Next diagnostic")
          map("n", "<leader>dd", vim.diagnostic.open_float, "Line diagnostics")
        end,
      })
    end,
  },
}
LUA
}

install_plugins_headless() {
  log "Installing Neovim plugins headless"
  nvim --headless "+Lazy! sync" +qa || {
    warn "Plugin sync failed. You can retry inside nvim with :Lazy sync"
  }

  # treesitter 파서를 동기로 설치해서 첫 실행 시 하이라이팅이 바로 동작하게 한다.
  log "Installing treesitter parsers"
  nvim --headless \
    "+lua require('nvim-treesitter').install({'lua','vim','vimdoc','bash','json','yaml','xml','html','css','javascript','typescript','java','sql','markdown','markdown_inline'}):wait(300000)" \
    +qa || {
    warn "Treesitter parser install failed. You can retry inside nvim with :TSUpdate"
  }

  # LSP 서버도 미리 설치한다.
  # headless 모드에서는 mason-lspconfig가 ensure_installed를 건너뛰므로
  # (중복 설치 경쟁 없음), MasonInstall로 직접 설치한다. headless에서는 동기로 동작한다.
  # --quiet: npm 등 설치 로그가 stderr로 중계되며 에러처럼 보이는 것을 방지. 실패는 exit code로 감지된다.
  log "Installing LSP servers via Mason"
  nvim --headless \
    "+MasonInstall --quiet lua-language-server typescript-language-server html-lsp css-lsp json-lsp yaml-language-server bash-language-server" \
    +qa || {
    warn "Mason install failed. You can retry inside nvim with :Mason"
  }
}

print_summary() {
  cat <<'TXT'

============================================================
Neovim setup completed.

Run:
  nvim

Main keymaps:
  <Space>e   Toggle file tree
  <Space>o   Focus file tree
  <Space>ff  Find files
  <Space>fg  Live grep
  <Space>fb  Buffers
  <Space>fr  Recent files
  <Space>tt  Toggle terminal
  gd         Go to definition
  gr         Find references
  K          Hover
  <Space>ca  Code action
  <Space>cf  Format

Health check:
  nvim
  :checkhealth
  :Lazy
  :Mason

Backup location:
  ~/.nvim-bootstrap-backup/<timestamp>
============================================================

TXT
}

main() {
  require_mint

  # sudo 세션 미리 확보
  sudo -v

  install_packages
  install_neovim
  install_tree_sitter_cli
  install_lazygit
  backup_old_nvim
  write_nvim_config
  install_plugins_headless
  print_summary
}

main "$@"
