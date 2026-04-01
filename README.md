# setup-vs-config

Configure **Visual Studio Code on Arch Linux** for a scientific,
scripting-heavy workflow with emphasis on:

- Bash / Zsh shell scripting
- Python
- R
- PowerShell
- Node.js / JavaScript / TypeScript
- Lua
- Markdown / LaTeX
- YAML / Docker
- C / C++ / CMake / Make
- Rust
- Java

The repository currently provides a single setup script:

- `setup-vs-bin.sh`

That script installs a curated set of VS Code extensions, writes a practical
`settings.json` and `keybindings.json`, and can optionally install selected
Arch-side helper packages.

---

## Why this exists

Configuring VS Code by hand is tedious and error-prone.

This script is meant to give a reproducible starting point for a workflow that
is more research-, scripting-, and tooling-oriented than generic web-only
editor setups.

It aims to be:

- practical rather than flashy
- opinionated but not reckless
- suitable for Arch Linux
- aware of common conflicts such as `nodejs` vs `nodejs-lts-*`
- compatible with using `radian` through `pipx` rather than unsafe `pip`
  patterns on system Python

---

## What the script does

`setup-vs-bin.sh` can:

1. detect or install the `code` CLI
2. back up existing VS Code user settings
3. install a curated extension set
4. write `settings.json`
5. write `keybindings.json`
6. optionally install recommended Arch packages
7. optionally install or upgrade `radian` via `pipx`

---

## Supported focus areas

### Primary emphasis

- shell scripting
- Python
- R
- PowerShell

### Secondary / future-oriented support

- JavaScript / TypeScript / Node.js
- Lua
- Markdown
- LaTeX
- YAML
- Docker
- C / C++
- Rust
- Java

---

## Requirements

- Arch Linux or an Arch-based system
- `sudo` privileges for package installation
- Visual Studio Code from the Arch repositories, or permission to install it
- internet access for extension installation

---

## Basic usage

```bash
chmod +x ./setup-vs-bin.sh
./setup-vs-bin.sh
```

### Back up existing VS Code settings first

```bash
./setup-vs-bin.sh --backup
```

### Install recommended helper packages too

```bash
./setup-vs-bin.sh --backup --install-packages
```

### Also install `radian`

```bash
./setup-vs-bin.sh --backup --install-packages --radian
```

### Use a specific VS Code binary

```bash
./setup-vs-bin.sh --code-bin /usr/bin/code
```

---

## Command-line options

| Option | Meaning |
|---|---|
| `--backup` | Back up existing `settings.json` and `keybindings.json` |
| `--install-packages` | Install recommended Arch helper packages |
| `--skip-packages` | Skip helper package installation |
| `--radian` | Install or upgrade `radian` via `pipx` |
| `--code-bin PATH` | Use a specific `code` executable |
| `-h`, `--help` | Show help text |

---

## Installed / configured extension categories

The script installs a curated set of extensions for:

- editor defaults and icons
- Git and Remote SSH
- Markdown
- shell scripting
- Python and Jupyter
- R
- PowerShell
- Lua
- YAML
- Docker
- C / C++ / CMake / Make
- Rust
- Java
- LaTeX

This is not meant to be a maximal extension dump. It is intended to remain
usable and maintainable.

---

## Arch package notes

When `--install-packages` is used, the script may install tools such as:

- `shellcheck`
- `shfmt`
- `python-black`
- `python-ruff`
- `lua-language-server`
- `rust-analyzer`
- `jdk21-openjdk`
- `cmake`
- `make`
- `gcc`
- `ripgrep`
- `fd`
- `unzip`

### Important Node.js note

The Arch package `bash-language-server` depends on `nodejs`.

That can conflict with an already installed `nodejs-lts-*` package.
The script therefore tries to avoid needlessly replacing an LTS Node runtime
just to satisfy that dependency.

---

## R and VS Code

VS Code support for R is materially better when these R packages are installed:

```r
install.packages(c(
  "languageserver",
  "jsonlite",
  "rlang",
  "httpgd"
))
```

Optional but often useful:

```r
install.packages(c(
  "lintr",
  "styler",
  "data.table",
  "renv"
))
```

---

## `radian`

On Arch Linux, `radian` should be installed with `pipx`, not with `pip --user`
against the system-managed Python installation.

Manual equivalent:

```bash
sudo pacman -S --needed python-pipx
pipx ensurepath
pipx install radian
```

If `radian` is unavailable, the script falls back to plain `R`.

---

## Output files

The script writes to:

```text
~/.config/Code/User/settings.json
~/.config/Code/User/keybindings.json
```

If `--backup` is used, backup copies are created with a timestamp suffix.

---

## Example workflow

A reasonably complete first run might look like this:

```bash
git clone git@github.com:Epineph/setup-vs-config.git
cd setup-vs-config
chmod +x ./setup-vs-bin.sh
./setup-vs-bin.sh --backup --install-packages --radian
```

Then:

1. fully quit VS Code
2. reopen VS Code
3. install the recommended R packages inside R
4. verify that the integrated terminal, formatting, and language support work
   as intended

---

## Caveats

- This script is opinionated.
- It is designed for **Arch Linux**, not for every Linux distribution.
- It writes user-level VS Code settings directly.
- Some extension behavior may still depend on external tools being on `PATH`.
- Java, PowerShell, LaTeX, and R workflows still require their own runtimes or
  toolchains where relevant.

---

## Repository structure

```text
.
└── setup-vs-bin.sh
```

If the project grows later, likely additions would be:

```text
README.md
LICENSE
.gitignore
examples/
```

---

## Suggested future improvements

Possible future directions:

- split extension lists by language or role
- add a dry-run mode
- support VSCodium separately
- support profile-specific settings
- export a minimal and a full setup mode
- validate installed extension IDs before applying

---

## License

Add the license you actually want to use.

If you do not know yet, MIT is a common simple choice for small utility
repositories.

---

## Maintainer

Repository owner: **Heini / Epineph**
