#!/bin/bash

set -eou pipefail

# include a line in a file
include() {
    grep -qxF "$1" "$2" || echo "$1" >>"$2"
}

####################
### DEPENDENCIES ###
####################
sudo apt-get -qq -y install tmux wget build-essential ripgrep

##############
### NEOVIM ###
##############
# Pinned to 0.11.x: nvim-treesitter's master branch (archived, used by init.lua)
# does not support Neovim 0.12 -- its query predicates/directives break because
# 0.12 passes node lists instead of single nodes. Bumping this to 0.12 requires
# migrating nvim-treesitter to its main branch rewrite first.
NVIM_VER="v0.11.7"
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
    echo "current version of neovim: ${CUR_VER}"
    if [ "$NVIM_VER" != "$CUR_VER" ]; then
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

#################
### LANGUAGES ###
#################

###############
### CONFIGS ###
###############

# dotfile specific config that will get updated on apply
cp .bashrc_local ~
if [ ! -f "~/.bashrc_extras" ]; then
    # any extra config that is not overwritten on apply
    cp .bashrc_extras ~ 
fi
cp .tmux.conf ~

# only for laptop
if [ "${1:-}" = "laptop" ]; then
    cp .xsessionrc ~
fi

include '. ~/.bashrc_local' ~/.bashrc
sed -i '/^#force_color_prompt=yes/s/^#//' ~/.bashrc
