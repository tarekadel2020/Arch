#!/bin/bash 

set -e


SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONFIG_FILE=$SCRIPT_DIR/install.conf

bash $SCRIPT_DIR/conf_install.sh
source $SCRIPT_DIR/install.conf
bash $SCRIPT_DIR/base_install.sh
