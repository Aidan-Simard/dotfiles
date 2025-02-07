#!/bin/bash

# NEOVIM_VER='v0.10.2'
# GO_VER='1.23.4'

# Copy all config files to requied locations:
# nvim/         -> ~/.conf/nvim/
# .bashrc       -> ~/.bashrc
# .tmux.conf    -> ~/.tmux.conf
# wsl.conf      -> /etc/wsl.conf

# Install ansible
sudo apt update
sudo apt install software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible

# Create dev directories
# mkdir ~/dev
# mkdir ~/dev/go

# sudo apt update -y && sudo apt upgrade -y

# Copy neovim configuration
# mkdir ~/.config
# cp -r nvim ~/.config

# Copy .bashrc, .tmux.conf, and wsl.conf
# cp .bashrc ~
# cp .tmux.conf ~
# sudo cp wsl.conf /etc/

# Install neovim
# https://github.com/neovim/neovim/blob/master/INSTALL.md#pre-built-archives-2
# curl -LO "https://github.com/neovim/neovim/releases/download/$NEOVIM_VER/nvim-linux64.tar.gz"
# sudo rm -rf /opt/nvim
# sudo tar -C /opt -xzf nvim-linux64.tar.gz
# rm nvim-linux64.tar.gz
# sudo apt install ripgrep python3-venv -y

# Install golang
# wget "https://go.dev/dl/go$GO_VER.linux-amd64.tar.gz"
# sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf "go$GO_VER.linux-amd64.tar.gz"
# rm "go$GO_VER.linux-amd64.tar.gz"
