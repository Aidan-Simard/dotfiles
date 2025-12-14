#!/bin/bash

include() {
    grep -qxF "$1" "$2" || echo "$1" >>"$2"
}

####################
### DEPENDENCIES ###
####################
sudo apt-get -qq -y install tmux wget build-essential

##############
### NEOVIM ###
##############
NVIM_VER="v0.11.4"
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
        echo "Want nvim $NVIM_VER, have $CUR_VER."
        sudo rm -rf /opt/nvim
        install_nvim
    fi
else
    echo "Installing nvim"
    install_nvim
fi

mkdir -p ~/.config/nvim
cp init.lua ~/.config/nvim

#################
### LANGUAGES ###
#################

###############
### CONFIGS ###
###############
cp .bashrc_local ~
cp .tmux.conf ~

# only for laptop
if [ "$1" = "laptop" ]; then
    cp .xsessionrc ~
fi

include '. ~/.bashrc_local' ~/.bashrc
sed -i '/^#force_color_prompt=yes/s/^#//' ~/.bashrc
