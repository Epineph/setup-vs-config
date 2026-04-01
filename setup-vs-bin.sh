#!/usr/bin/env bash

set -euo pipefail

#===============================================================================
# setup-vs-bin.sh
#
# Configure Visual Studio Code on Arch Linux for a shell/Python/R/PowerShell-
# centric workflow, while also preparing sane support for Node.js, Lua,
# Markdown, LaTeX, YAML, Docker, C/C++, Rust, and Java.
#
# This script:
#   1. Detects or installs VS Code (`code`) on Arch Linux.
#   2. Optionally backs up existing user settings.
#   3. Installs a curated set of extensions with verified marketplace IDs.
#   4. Writes a clean settings.json and keybindings.json.
#   5. Optionally installs recommended companion packages for Linux-side tools.
#
# Notes:
#   - The old setting `terminal.integrated.shell.linux` is obsolete; modern
#     VS Code uses terminal profiles and `terminal.integrated.defaultProfile`.
#   - `editor.codeActionsOnSave` now prefers enum values such as `explicit`
#     and `always` instead of legacy booleans.
#   - R support in VS Code is substantially better when the R packages
#     `languageserver`, `jsonlite`, and `rlang` are installed; `httpgd` is
#     recommended for the plot viewer, and `radian` is optional.
#
# Usage:
#   ./setup-vs-bin.sh
#   ./setup-vs-bin.sh --backup
#   ./setup-vs-bin.sh --backup --install-packages
#
# Examples:
#   ./setup-vs-bin.sh
#   ./setup-vs-bin.sh --backup
#   ./setup-vs-bin.sh --install-packages
#   ./setup-vs-bin.sh --backup --install-packages --radian
#   ./setup-vs-bin.sh --skip-packages --code-bin "$(command -v code)"
#
#===============================================================================

#-------------------------------------------------------------------------------
# Defaults
#-------------------------------------------------------------------------------
BACKUP=false
INSTALL_PACKAGES=false
INSTALL_RADIAN=false
SKIP_PACKAGES=false
CODE_BIN=""
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

: "${XDG_CONFIG_HOME:=${HOME}/.config}"
VSCODE_USER_DIR="${XDG_CONFIG_HOME}/Code/User"
SETTINGS_FILE="${VSCODE_USER_DIR}/settings.json"
KEYBINDINGS_FILE="${VSCODE_USER_DIR}/keybindings.json"

#-------------------------------------------------------------------------------
# Help
#-------------------------------------------------------------------------------
function show_help() {
  cat <<'EOF'
setup-vs-bin.sh

Configure Visual Studio Code on Arch Linux for a scientific and scripting-heavy
workflow.

Usage:
  setup-vs-bin.sh [options]

Options:
  --backup            Back up existing settings.json and keybindings.json.
  --install-packages  Install recommended Arch/Python helper packages.
  --skip-packages     Do not install helper packages.
  --radian            Install radian with pip if pip is available.
  --code-bin PATH     Use a specific `code` executable.
  -h, --help          Show this help text.

What gets installed/configured:
  - VS Code extensions for Bash, Python, Jupyter, R, PowerShell, Lua,
    Markdown, YAML, Docker, Git, C/C++, CMake, Rust, Java, and LaTeX.
  - Language-specific formatter/linter defaults.
  - Linux terminal profile defaults for bash/zsh/fish.
  - Keybindings aimed at practical editing rather than novelty.

Important package notes:
  - Bash tooling is materially better with: bash-language-server, shellcheck,
    shfmt.
  - Python tooling is materially better with: python-black, python-ruff.
  - R tooling is materially better with CRAN packages:
      languageserver, jsonlite, rlang, httpgd
    and optionally radian from PyPI.
  - Java language support needs a JDK. Java 21 is a safe target.

Examples:
  setup-vs-bin.sh
  setup-vs-bin.sh --backup
  setup-vs-bin.sh --install-packages
  setup-vs-bin.sh --backup --install-packages --radian
  setup-vs-bin.sh --skip-packages --code-bin /usr/bin/code
EOF
}

#-------------------------------------------------------------------------------
# Logging
#-------------------------------------------------------------------------------
function info() {
  printf '[INFO] %s\n' "$*"
}

function warn() {
  printf '[WARN] %s\n' "$*" >&2
}

function die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

#-------------------------------------------------------------------------------
# Argument parsing
#-------------------------------------------------------------------------------
function parse_args() {
  while (($# > 0)); do
    case "$1" in
      --backup)
        BACKUP=true
        ;;
      --install-packages)
        INSTALL_PACKAGES=true
        ;;
      --skip-packages)
        SKIP_PACKAGES=true
        ;;
      --radian)
        INSTALL_RADIAN=true
        ;;
      --code-bin)
        shift
        (($# > 0)) || die "Missing argument for --code-bin"
        CODE_BIN="$1"
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
    shift
  done

  if [[ "$INSTALL_PACKAGES" == true && "$SKIP_PACKAGES" == true ]]; then
    die "Use either --install-packages or --skip-packages, not both"
  fi
}

#-------------------------------------------------------------------------------
# Dependency / platform checks
#-------------------------------------------------------------------------------
function require_arch() {
  [[ -f /etc/arch-release ]] || \
    die "This script is written for Arch Linux or Arch-based systems"
}

function detect_code_bin() {
  if [[ -n "$CODE_BIN" ]]; then
    [[ -x "$CODE_BIN" ]] || die "Specified --code-bin is not executable"
    return 0
  fi

  if command -v code >/dev/null 2>&1; then
    CODE_BIN="$(command -v code)"
    return 0
  fi

  info "VS Code CLI not found; installing package 'code' from Arch repos"
  sudo pacman -S --needed code

  command -v code >/dev/null 2>&1 || \
    die "Installation finished, but 'code' is still not on PATH"

  CODE_BIN="$(command -v code)"
}

#-------------------------------------------------------------------------------
# Backups
#-------------------------------------------------------------------------------
function backup_existing_files() {
  [[ "$BACKUP" == true ]] || return 0

  mkdir -p "$VSCODE_USER_DIR"

  for file in "$SETTINGS_FILE" "$KEYBINDINGS_FILE"; do
    if [[ -f "$file" ]]; then
      cp -a "$file" "${file}.bak-${TIMESTAMP}"
      info "Backed up $(basename "$file") -> ${file}.bak-${TIMESTAMP}"
    fi
  done
}

#-------------------------------------------------------------------------------
# Recommended system packages
#-------------------------------------------------------------------------------
function install_arch_packages() {
  [[ "$SKIP_PACKAGES" == true ]] && return 0
  [[ "$INSTALL_PACKAGES" == true ]] || return 0

  local -a pkgs=(
    bash-language-server
    shellcheck
    shfmt
    python-black
    python-ruff
    lua-language-server
    rust-analyzer
    nodejs
    npm
    jdk21-openjdk
    cmake
    make
    gcc
    ripgrep
    fd
    unzip
  )

  info "Installing recommended Arch packages"
  sudo pacman -S --needed "${pkgs[@]}"

  if [[ "$INSTALL_RADIAN" == true ]]; then
    if command -v pip >/dev/null 2>&1; then
      info "Installing/updating radian with pip --user"
      python -m pip install --user --upgrade radian
    else
      warn "pip not found; skipping radian installation"
    fi
  fi
}

#-------------------------------------------------------------------------------
# Extension install helpers
#-------------------------------------------------------------------------------
function install_extension() {
  local ext="$1"
  info "Installing extension: ${ext}"
  "$CODE_BIN" --install-extension "$ext" --force >/dev/null 2>&1 || \
    warn "Failed to install extension: ${ext}"
}

function install_extensions() {
  local -a extensions=(
    EditorConfig.EditorConfig
    eamodio.gitlens
    ms-vscode-remote.remote-ssh
    yzhang.markdown-all-in-one
    DavidAnson.vscode-markdownlint
    PKief.material-icon-theme
    esbenp.prettier-vscode
    mads-hartmann.bash-ide-vscode
    timonwong.shellcheck
    mkhl.shfmt
    ms-python.python
    ms-python.vscode-pylance
    ms-python.black-formatter
    charliermarsh.ruff
    ms-toolsai.jupyter
    REditorSupport.r
    ms-vscode.PowerShell
    sumneko.lua
    redhat.vscode-yaml
    ms-azuretools.vscode-docker
    ms-vscode.cpptools
    ms-vscode.cmake-tools
    ms-vscode.makefile-tools
    rust-lang.rust-analyzer
    redhat.java
    James-Yu.latex-workshop
  )

  local ext
  for ext in "${extensions[@]}"; do
    install_extension "$ext"
  done
}

#-------------------------------------------------------------------------------
# Write settings
#-------------------------------------------------------------------------------
function write_settings() {
  mkdir -p "$VSCODE_USER_DIR"

  cat > "$SETTINGS_FILE" <<'EOF'
{
  "workbench.colorTheme": "Default Dark Modern",
  "workbench.iconTheme": "material-icon-theme",

  "editor.fontFamily": "Fira Code, JetBrains Mono, Hack, monospace",
  "editor.fontLigatures": true,
  "editor.fontSize": 14,
  "editor.lineHeight": 22,
  "editor.tabSize": 2,
  "editor.insertSpaces": true,
  "editor.detectIndentation": true,
  "editor.rulers": [80, 81, 100, 120],
  "editor.wordWrap": "off",
  "editor.renderWhitespace": "selection",
  "editor.renderControlCharacters": false,
  "editor.minimap.enabled": true,
  "editor.minimap.renderCharacters": false,
  "editor.guides.indentation": true,
  "editor.guides.bracketPairs": true,
  "editor.bracketPairColorization.enabled": true,
  "editor.smoothScrolling": true,
  "editor.cursorBlinking": "smooth",
  "editor.cursorSmoothCaretAnimation": "on",
  "editor.inlineSuggest.enabled": true,
  "editor.stickyScroll.enabled": true,
  "editor.formatOnSave": true,
  "editor.formatOnPaste": false,
  "editor.codeActionsOnSave": {
    "source.fixAll": "explicit",
    "source.organizeImports": "explicit"
  },

  "files.autoSave": "onFocusChange",
  "files.insertFinalNewline": true,
  "files.trimTrailingWhitespace": true,
  "files.trimFinalNewlines": true,
  "files.encoding": "utf8",
  "files.eol": "\n",
  "files.associations": {
    "*.Rprofile": "r",
    "*.Renviron": "shellscript",
    "*.zsh": "shellscript",
    ".env*": "dotenv"
  },

  "search.useIgnoreFiles": true,
  "search.useGlobalIgnoreFiles": true,
  "search.followSymlinks": false,
  "search.smartCase": true,
  "search.exclude": {
    "**/.git": true,
    "**/.Rproj.user": true,
    "**/.mypy_cache": true,
    "**/.pytest_cache": true,
    "**/__pycache__": true,
    "**/node_modules": true,
    "**/dist": true,
    "**/build": true,
    "**/.quarto": true
  },

  "explorer.confirmDelete": false,
  "explorer.confirmDragAndDrop": false,

  "git.enableSmartCommit": true,
  "git.autofetch": true,
  "git.confirmSync": false,
  "git.openRepositoryInParentFolders": "always",

  "terminal.integrated.fontFamily": "Fira Code, JetBrains Mono, monospace",
  "terminal.integrated.fontSize": 13,
  "terminal.integrated.scrollback": 200000,
  "terminal.integrated.cursorBlinking": true,
  "terminal.integrated.defaultProfile.linux": "zsh",
  "terminal.integrated.profiles.linux": {
    "bash": {
      "path": "/usr/bin/bash",
      "args": ["-l"]
    },
    "zsh": {
      "path": "/usr/bin/zsh",
      "args": ["-l"]
    },
    "fish": {
      "path": "/usr/bin/fish",
      "args": ["-l"]
    }
  },

  "telemetry.telemetryLevel": "off",
  "security.workspace.trust.untrustedFiles": "open",
  "extensions.ignoreRecommendations": false,
  "update.mode": "manual",

  "[shellscript]": {
    "editor.defaultFormatter": "mkhl.shfmt",
    "editor.tabSize": 2,
    "files.eol": "\n"
  },
  "bashIde.enableSourceErrorDiagnostics": true,
  "shellcheck.enable": true,
  "shellcheck.run": "onType",

  "[python]": {
    "editor.defaultFormatter": "ms-python.black-formatter",
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
      "source.fixAll": "explicit",
      "source.organizeImports": "explicit"
    }
  },
  "python.analysis.typeCheckingMode": "basic",
  "python.analysis.inlayHints.variableTypes": true,
  "python.analysis.inlayHints.functionReturnTypes": true,
  "python.analysis.autoImportCompletions": true,
  "python.terminal.activateEnvironment": true,
  "python.REPL.sendToNativeREPL": false,
  "black-formatter.importStrategy": "fromEnvironment",
  "ruff.importStrategy": "fromEnvironment",
  "ruff.nativeServer": "on",
  "ruff.organizeImports": true,

  "jupyter.askForKernelRestart": false,
  "jupyter.interactiveWindow.textEditor.executeSelection": true,
  "notebook.lineNumbers": "on",
  "notebook.output.textLineLimit": 200,

  "r.bracketedPaste": true,
  "r.alwaysUseActiveTerminal": true,
  "r.plot.useHttpgd": true,
  "r.sessionWatcher": true,
  "r.rterm.linux": "radian",
  "r.rterm.option": [
    "--no-save",
    "--no-restore"
  ],

  "[r]": {
    "editor.tabSize": 2,
    "editor.insertSpaces": true,
    "editor.formatOnSave": false
  },
  "[rmd]": {
    "editor.wordWrap": "on"
  },

  "powershell.codeFormatting.useCorrectCasing": true,
  "powershell.codeFormatting.openBraceOnSameLine": true,
  "powershell.codeFormatting.preset": "OTBS",
  "[powershell]": {
    "editor.tabSize": 2,
    "editor.insertSpaces": true
  },

  "Lua.hint.enable": true,
  "Lua.runtime.version": "LuaJIT",
  "Lua.diagnostics.globals": [
    "vim"
  ],
  "[lua]": {
    "editor.tabSize": 2,
    "editor.insertSpaces": true
  },

  "[javascript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  },
  "[javascriptreact]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  },
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  },
  "[typescriptreact]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  },
  "[json]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[jsonc]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[yaml]": {
    "editor.defaultFormatter": "redhat.vscode-yaml"
  },
  "[markdown]": {
    "editor.wordWrap": "on",
    "editor.quickSuggestions": {
      "comments": "off",
      "strings": "off",
      "other": "off"
    }
  },

  "eslint.format.enable": true,
  "prettier.useEditorConfig": true,

  "[rust]": {
    "editor.formatOnSave": true
  },
  "rust-analyzer.checkOnSave": true,
  "rust-analyzer.cargo.autoreload": true,

  "cmake.configureOnOpen": false,
  "makefile.configureOnOpen": false,

  "java.configuration.updateBuildConfiguration": "interactive",

  "latex-workshop.latex.autoBuild.run": "never",
  "latex-workshop.view.pdf.viewer": "tab",

  "markdownlint.config": {
    "MD013": false,
    "MD033": false
  }
}
EOF
}

#-------------------------------------------------------------------------------
# Write keybindings
#-------------------------------------------------------------------------------
function write_keybindings() {
  mkdir -p "$VSCODE_USER_DIR"

  cat > "$KEYBINDINGS_FILE" <<'EOF'
[
  {
    "key": "ctrl+alt+t",
    "command": "workbench.action.terminal.toggleTerminal"
  },
  {
    "key": "ctrl+shift+s",
    "command": "workbench.action.files.saveAll"
  },
  {
    "key": "ctrl+alt+b",
    "command": "gitlens.toggleFileBlame"
  },
  {
    "key": "ctrl+alt+r",
    "command": "r.runSelection"
  },
  {
    "key": "ctrl+enter",
    "command": "r.runSelection",
    "when": "editorTextFocus && editorLangId == 'r'"
  },
  {
    "key": "ctrl+enter",
    "command": "python.execSelectionInTerminal",
    "when": "editorTextFocus && editorLangId == 'python'"
  },
  {
    "key": "ctrl+shift+enter",
    "command": "workbench.action.terminal.runSelectedText"
  },
  {
    "key": "alt+z",
    "command": "editor.action.toggleWordWrap"
  },
  {
    "key": "ctrl+shift+/",
    "command": "editor.action.blockComment"
  },
  {
    "key": "ctrl+k ctrl+f",
    "command": "editor.action.formatDocument"
  }
]
EOF
}

#-------------------------------------------------------------------------------
# Post-run guidance
#-------------------------------------------------------------------------------
function print_post_install_notes() {
  cat <<'EOF'

Post-install notes:

1. R inside VS Code
   Install these in R for the best experience:

     install.packages(c(
       "languageserver",
       "jsonlite",
       "rlang",
       "httpgd"
     ))

   Optional:

     install.packages(c("lintr", "styler", "data.table", "renv"))

2. Radian
   If you want radian explicitly:

     python -m pip install --user --upgrade radian

   If radian is not on PATH, either add it to PATH or change `r.rterm.linux`
   in settings.json back to plain `R`.

3. Java
   Java support in this setup assumes a JDK is present. Java 21 is a safe and
   current baseline on Arch.

4. PowerShell
   For Linux-side PowerShell authoring/debugging, install PowerShell separately
   if you actually intend to run pwsh on Arch.

5. Restart VS Code
   Fully quit and reopen VS Code after the script finishes.
EOF
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
function main() {
  parse_args "$@"
  require_arch
  detect_code_bin
  backup_existing_files
  install_arch_packages
  install_extensions
  write_settings
  write_keybindings

  info "VS Code user directory: ${VSCODE_USER_DIR}"
  info "Settings written to: ${SETTINGS_FILE}"
  info "Keybindings written to: ${KEYBINDINGS_FILE}"

  print_post_install_notes
}

main "$@"
