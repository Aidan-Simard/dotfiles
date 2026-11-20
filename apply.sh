#!/bin/bash

set -eou pipefail

# include a line in a file
include() {
    grep -qxF "$1" "$2" || echo "$1" >>"$2"
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

#################
### LANGUAGES ###
#################

# --- ASDF & Node.js ---
# --- Node.js (via nvm) ---
# Skip if nvm is already installed
if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
# Install Node.js LTS if not already installed
if ! command -v node >/dev/null 2>&1 || [ "$(node -v 2>/dev/null)" != "v24.22.0" ]; then
    nvm install lts
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

# only for laptop
if [ "${1:-}" = "laptop" ]; then
    cp .xsessionrc ~
fi

# source extra config (which in turn loads machine-local config) from ~/.bashrc
include '. ~/.bashrc_extras' ~/.bashrc
sed -i '/^#force_color_prompt=yes/s/^#//' ~/.bashrc

# sync language-related shell env into .bashrc_extras; nvm and Go manual install
include 'export PATH="$HOME/.nvm:$PATH"' ~/.bashrc_extras
include '[ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh"' ~/.bashrc_extras
include 'export PATH="$HOME/.local/go/go/bin:$PATH"' ~/.bashrc_extras

# add current user to sudoers
RULE="$(whoami) ALL=(ALL) NOPASSWD: ALL"
SUDOERS_FILE="/etc/sudoers.d/$(whoami)"
if [ ! -f "$SUDOERS_FILE" ] || ! sudo grep -qxF "$RULE" "$SUDOERS_FILE" 2>/dev/null; then
    echo "$RULE" | sudo tee "$SUDOERS_FILE" >/dev/null
    sudo chmod 0440 "$SUDOERS_FILE"
fi
