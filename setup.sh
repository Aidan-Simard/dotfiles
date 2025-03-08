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

ansible-playbook setup.yaml --ask-become-pass

source ~/.bashrc
