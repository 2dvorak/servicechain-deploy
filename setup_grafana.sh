#!/bin/bash

set -e

PROJ_PATH=$(pwd)
pushd klaytn-ansible
cp roles/klaytn_grafana/tutorial/grafana_setup.yml .
ansible-playbook -i $PROJ_PATH/inventory.grafana grafana_setup.yml --key-file $HOME/.ssh/servicechain-deploy-key

popd
