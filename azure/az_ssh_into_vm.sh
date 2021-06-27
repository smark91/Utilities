#!/bin/bash

#######################
# The script will look into azure and guide you to select a VM given you the option to directly connect or print the public FQDN to let you connect.
# If HISTFILE var is filled it will save the ssh command in the history file to easily reconnect without running again the script
#######################

DEFAULT_USER="myadminuser" # Default user suggested on login
HISTFILE='/home/user/.zsh_history' # History file location to register past connection

# Check for prerequisites
command -v az >/dev/null 2>&1 || { echo >&2 "I require az but it's not installed.  Aborting."; exit 1; }
command -v fzf >/dev/null 2>&1 || { echo >&2 "I require fzf but it's not installed.  Aborting."; exit 1; }

# Interactively choose subscription, resource group and VM
ACCOUNT=$(az account list --query '[].name' -o tsv | fzf)
if [ -z "$ACCOUNT" ]; then exit 1; fi
RG=$(az group list --subscription "$ACCOUNT" --query '[].name' -o tsv | fzf)
if [ -z "$RG" ]; then exit 1; fi
VM=$(az vm list --subscription "$ACCOUNT" --resource-group "$RG" --query '[].name' -o tsv | fzf)
if [ -z "$VM" ]; then exit 1; fi
echo "Retriving VM FQDN ..."
VM_NIC=$(az vm show --subscription "$ACCOUNT" --resource-group "$RG" --name "$VM" --query 'networkProfile.networkInterfaces[0].id' -o tsv)
NIC_PIP=$(az network nic show --ids "$VM_NIC" --query 'ipConfigurations[0].publicIpAddress.id' -o tsv)
PIP_FQDN=$(az network public-ip show --id "$NIC_PIP" --query 'dnsSettings.fqdn' -o tsv)

read -e -r -p "Want to SSH into it [Y\n]? " RESULT
RESULT=${RESULT:-Y}

if [ "$RESULT" = "y" ] || [ "$RESULT" = "Y" ]; then
    read -e -r -p "SSH Username [$DEFAULT_USER]: " USER
    USER=${USER:-$DEFAULT_USER}
    set -o history
    history -s "ssh $USER@$PIP_FQDN # Sub: $ACCOUNT | RG: $RG | VM: $VM"
    ssh "$USER@$PIP_FQDN"
else
    echo "FQDN: $PIP_FQDN"
fi
