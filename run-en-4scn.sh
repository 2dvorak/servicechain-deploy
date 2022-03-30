#!/bin/bash

PROJ_PATH=$(pwd)
set -e

# Check if terraform.tfvars exists
if [[ ! -f "$(pwd)/klaytn-terraform/service-chain-aws/deploy-4scn/terraform.tfvars" ]]
then
	echo "Please prepare the configuration file for the klaytn-terraform."
	exit 1
fi

# Run terraform
./1.run_terraform.sh

# Run ansible klaytn_node
./2.setup_nodes.sh

## Wait 30 seconds for the Klaytn services to be restarted
echo "Waiting 30 seconds for the Klaytn services to be restarted"
sleep 30

# Wait until EN sync finished
echo "The newly deployed EN node should be synced to latest block. This could take about 30~40 minutes, up to few hours."
pushd klaytn-terraform/service-chain-aws/deploy-4scn
EN_PUBLIC_IP_LIST=($(terraform show -json | jq -r '.values.root_module.resources[] | select(.address | startswith("aws_eip_association.en")) | .values.public_ip'))
EN_IP=${EN_PUBLIC_IP_LIST[0]}
popd

## Reset timer to track elapsed time
SECONDS=0
while :
do
	EN_SYNCING=$(ssh ec2-user@$EN_IP "sudo ken attach /var/kend/data/klay.ipc --exec klay.syncing")
	DURATION=$SECONDS
	if [[ $EN_SYNCING == false ]]; then
		echo "EN node sync with Baobab finished in $(($DURATION / 60))m $(($DURATION % 60))s"
		break
	fi
	EN_BLOCK_NUM=$(ssh ec2-user@$EN_IP "sudo ken attach /var/kend/data/klay.ipc --exec klay.blockNumber")
	BAOBAB_BLOCK_NUM=$(ssh ec2-user@$EN_IP "sudo ken attach https://api.baobab.klaytn.net:8651 --exec klay.blockNumber")
	echo -ne "Syncing EN node with Baobab... ($(($DURATION / 60))m $(($DURATION % 60))s elapsed, $EN_BLOCK_NUM/$BAOBAB_BLOCK_NUM blocks synced)"\\r
	sleep 3
done

# Run ansible klaytn_bridge
./3.setup_bridge.sh

## Wait 30 seconds for the Klaytn services to be restarted
echo "Waiting 30 seconds for the Klaytn services to be restarted"
sleep 30

