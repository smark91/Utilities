#!/bin/bash

###############
# The script create a temporary rule on a VM firewall using your current public IP than it will wait until a key is pressed to remove it
###############

# Check for prerequisites
command -v az >/dev/null 2>&1 || { echo >&2 "I require az but it's not installed.  Aborting."; exit 1; }
command -v fzf >/dev/null 2>&1 || { echo >&2 "I require fzf but it's not installed.  Aborting."; exit 1; }

# Interactively choose subscription, resource group and VM
ACCOUNT=$(az account list --query '[].name' -o tsv | fzf)
RG=$(az group list --subscription "$ACCOUNT" --query '[].name' -o tsv | fzf)
VM=$(az vm list --subscription "$ACCOUNT" --resource-group "$RG" --query '[].name' -o tsv | fzf)
VM_NIC=$(az vm show --subscription "$ACCOUNT" --resource-group "$RG" --name "$VM" --query 'networkProfile.networkInterfaces[0].id' -o tsv )
NIC_NSG=$(az network nic show --ids "$VM_NIC" --query 'networkSecurityGroup.id' -o tsv)
NSG_NAME=$(az network nsg show --ids "$NIC_NSG" --query 'name' -o tsv)

# Ask for rule values
read -p "Rule name: " RULE_NAME
read -p "Port ranges (e.g. 80 or 80-88 or 80,88): " PORT_RANGES
printf  "\nCurrent rule and priority:\n"
az network nsg rule list --subscription "$ACCOUNT" --resource-group "$RG" --nsg-name "$NSG_NAME" --query '[].[priority, name]' -o tsv | sort -h
read -p "Priority [100-4096]: " PRIORITY

# Appling rule
printf  "\nAppling rule..."
az network nsg rule create --subscription "$ACCOUNT" -g "$RG" --nsg-name "$NSG_NAME" --name "$RULE_NAME" --source-address-prefixes "$(curl -s ipconfig.io)/32" --destination-port-ranges "$PORT_RANGES" --access Allow --protocol Tcp --priority "$PRIORITY" --query 'provisioningState' -o tsv

# Wait for ESC input
printf  "Press ESC key to remove the rule or CTRL-C to leave it"
while read -r -n1 key
do
    if [[ $key == $'\e' ]]; then
        break;
    fi
done

# Remove rule
az network nsg rule delete --subscription "$ACCOUNT" -g "$RG" --nsg-name "$NSG_NAME" --name "$RULE_NAME"
