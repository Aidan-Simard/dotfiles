#!/bin/bash

set -eou pipefail

# Usage: ./apply.sh [-A|--all] [--laptop]
#   (default)  install the minimal dev environment: tmux, neovim, tree-sitter,
#              shell config, and essential CLI tools
#   -A, --all  also install language toolchains (nvm/node, Go, uv), their
#              shell environment, and the Pi coding agent
#   --laptop   also install the laptop-specific .xsessionrc

INSTALL_ALL=false
INSTALL_LAPTOP=false

usage() {
    sed -n '5,11p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        -A|--all) INSTALL_ALL=true ;;
        --laptop) INSTALL_LAPTOP=true ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

# include a line in a file
include() {
    grep -qxF "$1" "$2" || echo "$1" >>"$2"
}

# remove an exact line from a file (used to migrate old language env lines)
remove_line() {
    [ -f "$2" ] || return 0
    grep -vxF "$1" "$2" >"$2.tmp" || true
    mv "$2.tmp" "$2"
}

####################
### DEPENDENCIES ###
####################
if command -v apt-get >/dev/null 2>&1; then
    PKG_MGR=apt
elif command -v dnf >/dev/null 2>&1; then
    PKG_MGR=dnf
else
    echo "Unsupported distro: neither apt-get nor dnf found" >&2
    exit 1
fi

if [ "$PKG_MGR" = "apt" ]; then
    sudo apt-get -qq -y install tmux wget build-essential ripgrep xclip wl-clipboard curl git python3-venv
else
    # Fedora: gcc/gcc-c++/make replace build-essential; venv ships with python3
    sudo dnf -y install tmux wget gcc gcc-c++ make ripgrep xclip wl-clipboard curl git python3
fi

##############
### NEOVIM ###
##############
# nvim-treesitter runs its main branch rewrite (requires Neovim >= 0.12);
# keep in sync with branch = 'main' in init.lua.
NVIM_VER="v0.12.5"
install_nvim() {
    NVIM_DIR="nvim-linux-x86_64"
    NVIM_TAR="${NVIM_DIR}.tar.gz"
    wget -q "https://github.com/neovim/neovim/releases/download/${NVIM_VER}/${NVIM_TAR}"
    tar xaf $NVIM_TAR
    rm $NVIM_TAR
    mv $NVIM_DIR nvim
    sudo mv nvim /opt
}
if [ -f "/opt/nvim/bin/nvim" ]; then
    CUR_VER=$(/opt/nvim/bin/nvim --version 2>/dev/null | head -n 1 | awk '{print $2}')
    if [ "$NVIM_VER" != "$CUR_VER" ]; then
        echo "current version of neovim: ${CUR_VER}"
        sudo rm -rf /opt/nvim
        install_nvim
        echo "installed neovim ${NVIM_VER}"
    fi
else
    install_nvim
    echo "installed neovim ${NVIM_VER}"
fi

mkdir -p ~/.config/nvim
cp init.lua ~/.config/nvim

###################
### TREE-SITTER ###
###################
# required by nvim-treesitter's main branch to compile parsers
TS_VER="v0.27.0"
if ! ~/.local/bin/tree-sitter --version 2>/dev/null | grep -q "${TS_VER#v}"; then
    mkdir -p ~/.local/bin
    wget -qO /tmp/tree-sitter.gz "https://github.com/tree-sitter/tree-sitter/releases/download/${TS_VER}/tree-sitter-linux-x64.gz"
    gunzip -cf /tmp/tree-sitter.gz > ~/.local/bin/tree-sitter
    rm /tmp/tree-sitter.gz
    chmod +x ~/.local/bin/tree-sitter
    echo "installed tree-sitter ${TS_VER}"
fi

############################
### LANGUAGES (--all)    ###
############################
install_languages() {
    # --- Node.js (via nvm) ---
    # Skip if nvm is already installed
    if [ ! -d "$HOME/.nvm" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    fi

    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

    # Install Node.js LTS if not already installed
    if ! command -v node >/dev/null 2>&1 || [ "$(nvm version lts/* 2>/dev/null)" = "N/A" ]; then
        nvm install --lts
    fi

    # --- Go (manual tarball) ---
    # Go is installed manually to $HOME/.local/go
    unset GOROOT 2>/dev/null || true
    if [ ! -d "$HOME/.local/go/go/bin" ]; then
        # Download Go tarball
        GO_VER="1.27.2"
        curl -LO https://go.dev/dl/go${GO_VER}.linux-amd64.tar.gz
        rm -rf "$HOME/.local/go"
        mkdir -p "$HOME/.local/go"
        tar -C "$HOME/.local/go" -xzf "go${GO_VER}.linux-amd64.tar.gz"
        rm "go${GO_VER}.linux-amd64.tar.gz"
    fi

    # --- UV (Python package manager) ---
    if ! command -v uv >/dev/null 2>&1; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
    fi

    # shell environment for the language toolchains
    cp .bashrc_languages ~/.bashrc_languages
}

install_pi() {
    local agent_dir="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
    local pi_bin="$agent_dir/bin/pi"

    if [ -f "$agent_dir/install/managed-install.json" ] && [ -x "$pi_bin" ]; then
        # Already a managed install: let Pi update itself. This is a no-op when
        # there is no newer release, so repeated --all runs don't reinstall.
        if ! "$pi_bin" update; then
            echo "install_pi: 'pi update' failed; keeping the existing install" >&2
        fi
    else
        # No managed install yet (fresh machine or legacy npm install): use Pi's
        # official installer, which installs the latest release into
        # ~/.pi/agent. setsid detaches it from the controlling terminal so its
        # interactive confirmation menu is skipped and it proceeds with the
        # default install/migrate action.
        if command -v setsid >/dev/null 2>&1; then
            setsid -w sh -c 'curl -fsSL https://pi.dev/install.sh | sh'
        else
            curl -fsSL https://pi.dev/install.sh | sh
        fi
    fi

    # The managed installer puts the launcher in ~/.pi/agent/bin, which is not
    # on PATH. ~/.local/bin is, so expose it there.
    if [ -x "$pi_bin" ]; then
        mkdir -p "$HOME/.local/bin"
        ln -sfn "$pi_bin" "$HOME/.local/bin/pi"
    fi
}

if $INSTALL_ALL; then
    install_languages
    install_pi
fi

export PATH="$HOME/.local/bin:$PATH"

###############
### CONFIGS ###
###############

# machine-local bashrc; only created if missing, never overwritten on apply
if [ ! -f "$HOME/.bashrc_local" ]; then
    cp .bashrc_local ~
fi

# extra config to bashrc; only seeded if missing, kept in sync by the includes below
if [ ! -f "$HOME/.bashrc_extras" ]; then
    cp .bashrc_extras ~
fi

cp .tmux.conf ~

# Pi agent config: settings + themes only. Credentials (auth.json), sessions,
# and the model cache are deliberately never tracked and are left untouched.
mkdir -p ~/.pi/agent/themes
cp pi-agent/settings.json ~/.pi/agent/settings.json
cp pi-agent/themes/*.json ~/.pi/agent/themes/

# only for laptop
if $INSTALL_LAPTOP; then
    cp .xsessionrc ~
fi

# source extra config (which in turn loads machine-local config) from ~/.bashrc
include '. ~/.bashrc_extras' ~/.bashrc

sed -i '/^#force_color_prompt=yes/s/^#//' ~/.bashrc

# keep the language env for machines that already have toolchains installed,
# even when applying the minimal environment
if [ -d "$HOME/.nvm" ] || [ -d "$HOME/.local/go" ]; then
    [ -f "$HOME/.bashrc_languages" ] || cp .bashrc_languages ~/.bashrc_languages
fi

# migrate language env out of .bashrc_extras (now lives in .bashrc_languages)
remove_line 'export NVM_DIR="$HOME/.nvm"' ~/.bashrc_extras
remove_line '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' ~/.bashrc_extras
remove_line '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' ~/.bashrc_extras
remove_line '[ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh"' ~/.bashrc_extras
remove_line 'export PATH="$HOME/.nvm:$PATH"' ~/.bashrc_extras
remove_line 'export PATH="$HOME/.local/go/go/bin:$PATH"' ~/.bashrc_extras
remove_line 'export PATH="$(go env GOPATH)/bin:$PATH"' ~/.bashrc_extras

# source language toolchain env if it has been installed with --all
include '[ -f ~/.bashrc_languages ] && . ~/.bashrc_languages' ~/.bashrc_extras

# add current user to sudoers
RULE="$(whoami) ALL=(ALL) NOPASSWD: ALL"
SUDOERS_FILE="/etc/sudoers.d/$(whoami)"
if [ ! -f "$SUDOERS_FILE" ] || ! sudo grep -qxF "$RULE" "$SUDOERS_FILE" 2>/dev/null; then
    echo "$RULE" | sudo tee "$SUDOERS_FILE" >/dev/null
    sudo chmod 0440 "$SUDOERS_FILE"
fi
