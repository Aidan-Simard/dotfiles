#!/bin/bash

ansible-playbook setup.playbook.yaml --ask-become-pass --verbose

source ~/.bashrc

