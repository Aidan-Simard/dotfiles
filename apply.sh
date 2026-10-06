#!/bin/bash

set -eou pipefail

# include a line in a file
include() {
    grep -qxF "$1" "$2" || echo "$1" >>"$2"
}

####################
### DEPENDENCIES ###
####################
sudo apt-get -qq -y install tmux wget build-essential ripgrep xclip curl git

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
ASDF_DIR="$HOME/.asdf"
if [ ! -d "$ASDF_DIR" ]; then
    git clone https://github.com/asdf-vm/asdf.git "$ASDF_DIR" --branch v0.14.0
fi

# Load asdf for current script process and subshells
. "$HOME/.asdf/asdf.sh"
export PATH="$HOME/.asdf/shims:$HOME/.asdf/bin:$PATH"

# Install Node.js plugin and latest LTS release
asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git || true
NODE_VER="lts"
asdf install nodejs "$NODE_VER"
asdf global nodejs "$NODE_VER"

# --- Go ---
asdf plugin add golang https://github.com/asdf-community/asdf-golang.git || true
GO_VER="1.27.1"
asdf install golang "$GO_VER"
asdf global golang "$GO_VER"

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

# sync language-related shell env into .bashrc_extras; asdf must come before golang set-env
include '. "$HOME/.asdf/asdf.sh"' ~/.bashrc_extras
include '. "$HOME/.asdf/completions/asdf.bash"' ~/.bashrc_extras
include '[ -f "${ASDF_DATA_DIR:-$HOME/.asdf}/plugins/golang/set-env.bash" ] && . "${ASDF_DATA_DIR:-$HOME/.asdf}/plugins/golang/set-env.bash"' ~/.bashrc_extras
include 'export PATH="$HOME/.local/bin:$PATH"' ~/.bashrc_extras

# add aidan to sudoers
RULE="aidan ALL=(ALL) NOPASSWD: ALL"
if [ ! -f /etc/sudoers.d/aidan ] || ! sudo grep -qxF "$RULE" /etc/sudoers.d/aidan 2>/dev/null; then
    echo "$RULE" | sudo tee /etc/sudoers.d/aidan >/dev/null
    sudo chmod 0440 /etc/sudoers.d/aidan
fi
