#!/bin/bash
# Arguments
# -s Subscription Name
# -r Resource group name
# -l Location Name
# -a Local admin name
# -p Local admin password
# -i Image name
#
#   Executing it with minimum parameters:
#   ./azuredeploy.sh -s pmcazure -r bash1-rg -l westus
#
# This script assumes that you already executed "az login" to authenticate 

while getopts s:r:l:p:a:i: option
do
	case "${option}"
	in
		s) SUB=${OPTARG};;
		r) RESOURCEGROUP=${OPTARG};;
		l) LOCATION=${OPTARG};;
		a) ADMINUSERNAME=${OPTARG};;
		p) PASSWORD=${OPTARG};;
		i) IMAGE=${OPTARG};;
	esac
done

# Functions
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"   # remove leading whitespace characters
    var="${var%"${var##*[![:space:]]}"}"   # remove trailing whitespace characters
    echo -n "$var"
}

# Setting up some default values if not provided
if [ -z ${ADMINUSERNAME} ]; then ADMINUSERNAME="localadmin"; fi 
if [ -z ${PASSWORD} ]; then PASSWORD="Test@2016-123!"; fi 
if [ -z ${IMAGE} ]; then IMAGE="CentOS"; fi

# az vm image list -> Lists default images  
# az vm image list --all -> Lists all images

echo "Input parameters"
echo "   subscription ${SUB}"
echo "   location ${LOCATION}"
echo "   image ${IMAGE}"
echo "   resource group ${RESOURCEGROUP}" ; echo
echo "Selecting subscription ${SUB}"
az account set --subscription $SUB

#--------------------------------------------
# Creating Resource Group
#-------------------------------------------- 
echo "Creating resource group  ${RESOURCEGROUP}"
RESULT=$(az group exists -n $RESOURCEGROUP)
if [ "$RESULT" != "true" ]
then
	az group create -l $LOCATION -n $RESOURCEGROUP
else
	echo "   Resource group ${RESOURCEGROUP} already exists"
fi

#--------------------------------------------
# Defining the environment in JSON format
#-------------------------------------------- 

# Storage accounts
STORAGEACCOUNTNAME1=$(< /dev/urandom tr -dc a-z0-9 | head -c 22)
STORAGEACCOUNTNAME2=$(< /dev/urandom tr -dc a-z0-9 | head -c 22)

STORAGEACCOUNTS='
[
	{
		"name":  "'${STORAGEACCOUNTNAME1}'",
        "containers":  [
							"vhds",
                            "test"
                    	],
    	"type":  "Standard_LRS",
        "resourceGroupName":  "'${RESOURCEGROUP}'",
        "kind":  "Storage",
        "location":  "'${LOCATION}'"
	},
	{
		"name":  "'${STORAGEACCOUNTNAME2}'",
        "containers":  [
							"vhds",
                            "test"
                    	],
    	"type":  "Standard_LRS",
        "resourceGroupName":  "'${RESOURCEGROUP}'",
        "kind":  "Storage",
        "location":  "'${LOCATION}'"
	}
]
'

# Network Security Groups
NSGS='
[
    {
        "rules": [
            {
                "destinationPortRange": "*",
                "description": "Block-UDP description",
                "priority": 300,
                "sourceAddressPrefix": "*",
                "direction": "Inbound",
                "destinationAddressPrefix": "*",
                "name": "Block-UDP",
                "sourcePortRange": "*",
                "access": "Deny",
                "protocol": "Udp"
            },
            {
                "destinationPortRange": "*",
                "description": "Allow ping description",
                "priority": 1000,
                "sourceAddressPrefix": "*",
                "direction": "Inbound",
                "destinationAddressPrefix": "*",
                "name": "AllowPing",
                "sourcePortRange": "*",
                "access": "Allow",
                "protocol": "*"
            },
            {
                "destinationPortRange": "*",
                "description": "Block TCP description",
                "priority": 200,
                "sourceAddressPrefix": "*",
                "direction": "Inbound",
                "destinationAddressPrefix": "*",
                "name": "Block-TCP",
                "sourcePortRange": "*",
                "access": "Deny",
                "protocol": "Tcp"
            },
            {
                "destinationPortRange": "22",
                "description": "Allows SSH description",
                "priority": 100,
                "sourceAddressPrefix": "Internet",
                "direction": "Inbound",
                "destinationAddressPrefix": "*",
                "name": "allow-ssh",
                "sourcePortRange": "*",
                "access": "Allow",
                "protocol": "Tcp"
            }
        ],
        "name": "NSG01",
        "resourceGroupName": "'${RESOURCEGROUP}'",
        "location": "'${LOCATION}'"
    }
]
'

# Virtual Networks
VNETS='
[
    {
        "name": "vnet-test-02",
        "resourceGroupName": "'${RESOURCEGROUP}'",
        "location": "'${LOCATION}'",
        "addressSpaces": [
            {
                "name": "10.1.0.0/16",
                "subnets": [
                    {
                        "addressRange": "10.1.0.0/24",
                        "networkSecurityGroup": "NSG01",
                        "name": "subnet03"
                    },
                    {
                        "addressRange": "10.1.1.0/24",
                        "networkSecurityGroup": "",
                        "name": "subnet05"
                    }
                ]
            },
            {
                "name": "192.168.0.0/16",
                "subnets": [
                    {
                        "addressRange": "192.168.0.0/24",
                        "networkSecurityGroup": "NSG01",
                        "name": "subnet01"
                    }
                ]
            },
            {
                "name": "172.16.0.0/16",
                "subnets": [
                    {
                        "addressRange": "172.16.0.0/24",
                        "networkSecurityGroup": "NSG01",
                        "name": "subnet04"
                    }
                ]
            } 
        ]
    },
    {
        "name": "vnet-test-01",
        "resourceGroupName": "'${RESOURCEGROUP}'",
        "location": "'${LOCATION}'",
        "addressSpaces": [
            {
                "name": "10.0.0.0/16",
                "subnets": [
                    {
                        "addressRange": "10.0.0.0/24",
                        "networkSecurityGroup": "",
                        "name": "subnet01"
                    }
                ]
            }
        ]
    },
    {
        "addressSpaces": [],
        "name": "vnet-test-03",
        "resourceGroupName": "'${RESOURCEGROUP}'",
        "location": "'${LOCATION}'"
    }
]
'

# Public Ip Addresses
PIPS='
[
    {
        "name": "linux01-pip",
        "resourceGroupName": "'${RESOURCEGROUP}'",
        "location": "'${LOCATION}'",
        "allocationMethod": "Dynamic"
    },
    {
        "name": "linux02-pip",
        "resourceGroupName": "'${RESOURCEGROUP}'",
        "location": "'${LOCATION}'",
        "allocationMethod": "Dynamic"
    }
]
'

# Linux VMs
LINUXVMS='
[
    {
        "subnet": "subnet01",
        "virtualNetwork": "vnet-test-02",
        "credential": {
			"adminUsername":"'${ADMINUSERNAME}'",
			"adminPassword":"'${PASSWORD}'"
			},
        "name": "linux02",
        "vmImage": "'${IMAGE}'",
        "storageAccount":  "'${STORAGEACCOUNTNAME2}'",
        "vmType": "linux",
        "location": "'${LOCATION}'",
        "vmSize": "Standard_D1_v2",
        "resourceGroupName": "'${RESOURCEGROUP}'",
        "publicIpAddress": "linux02-pip"
    },
    {
        "subnet": "subnet01",
        "virtualNetwork": "vnet-test-01",
        "credential": {
			"adminUsername":"'${ADMINUSERNAME}'",
			"adminPassword":"'${PASSWORD}'"
			},
        "name": "linux01",
        "vmImage": "'${IMAGE}'",
        "storageAccount":  "'${STORAGEACCOUNTNAME1}'",
        "vmType": "linux",
        "location": "'${LOCATION}'",
        "vmSize": "Standard_D1_v2",
        "resourceGroupName": "'${RESOURCEGROUP}'",
        "publicIpAddress": "linux01-pip"
    }
]
'

#--------------------------------------------
# Creating storage accounts
#-------------------------------------------- 
readarray -t SAARR < <( echo $STORAGEACCOUNTS | jq -c '.[]')

for ITEM in "${SAARR[@]}"
do
	SANAME=$(echo "${ITEM}" | jq -r .name)
	SALOC=$(echo "${ITEM}" | jq -r .location)
	SARG=$(echo "${ITEM}" | jq -r .resourceGroupName)
	SAKIND=$(echo "${ITEM}" | jq -r .kind)
	SASKU=$(echo "${ITEM}" | jq -r .type)

	RESULT=$(az storage account show -g "$SARG" -n "$SANAME")
	if [ "$RESULT"  == "" ]
	then
		az storage account create -l "$SALOC" -n "$SANAME" -g "$SARG" --kind "$SAKIND" --sku "$SASKU"
	else
		echo "Storage account ${SANAME} already exists."
	fi
done

#--------------------------------------------
# Creating NSGs
#-------------------------------------------- 
readarray -t NSGARR < <( echo "$NSGS" | jq -c '.[]')

for ITEM in "${NSGARR[@]}"
do

	NSGNAME=$(echo "${ITEM}" | jq -r .name)
	NSGLOC=$(echo "${ITEM}" | jq -r .location)
	NSGRG=$(echo "${ITEM}" | jq -r .resourceGroupName)

    # Checking if NSG is already created
	RESULT=$(az network nsg show -g "$NSGRG" -n "$NSGNAME")
	if [ "$RESULT"  == "" ]
	then
		az network nsg create -g "$NSGRG" -l "$NSGLOC" -n "$NSGNAME"
	else
		echo "NSG  ${NSGNAME} already exists."
	fi

    # Creatig NSG rules
    NSGRULEARR=""
    readarray -t NSGRULEARR < <( echo "${ITEM}" | jq -c '.rules[]')

    for ITEMRULE in "${NSGRULEARR[@]}"
    do
        # Getting NSG name
        NAME=$(echo "${ITEMRULE}" | jq -r .name)

        # Checking if NSG rule is already created
        RESULT=$(az network nsg rule show --nsg-name "$NSGNAME" -g "$NSGRG" --name "$NAME")

        if [ "$RESULT"  == "" ]
        then
            DESTINATIONPORTRANGE=$(echo "${ITEMRULE}" | jq -r .destinationPortRange)
            DESCRIPTION=$(echo "${ITEMRULE}" | jq -r .description)
            PRIORITY=$(echo "${ITEMRULE}" | jq -r .priority)
            SOURCEADDRESSPREFIX=$(echo "${ITEMRULE}" | jq -r .sourceAddressPrefix)
            DIRECTION=$(echo "${ITEMRULE}" | jq -r .direction)
            DESTINATIONADDRESSPREFIX=$(echo "${ITEMRULE}" | jq -r .destinationAddressPrefix)
            SOURCEPORTRANGE=$(echo "${ITEMRULE}" | jq -r .sourcePortRange)
            ACCESS=$(echo "${ITEMRULE}" | jq -r .access)
            PROTOCOL=$(echo "${ITEMRULE}" | jq -r .protocol)

            az network nsg rule create --resource-group "$NSGRG" \
                --nsg-name "$NSGNAME" \
                --description "$DESCRIPTION" \
                --name "$NAME" \
                --protocol "$PROTOCOL" \
                --direction "$DIRECTION" \
                --priority "$PRIORITY" \
                --source-address-prefix "$SOURCEADDRESSPREFIX" \
                --source-port-range "$SOURCEPORTRANGE" \
                --destination-address-prefix "$DESTINATIONADDRESSPREFIX" \
                --destination-port-range "$DESTINATIONPORTRANGE" \
                --access "$ACCESS" 
        else
            echo "NSG rule ${NAME} already exists."
        fi
    done
done

#--------------------------------------------
# Creating Virtual Networks
#-------------------------------------------- 
readarray -t VNETARR < <( echo "$VNETS" | jq -c '.[]')

for ITEM in "${VNETARR[@]}"
do
	VNETNAME=$(echo "${ITEM}" | jq -r .name)
	VNETRG=$(echo "${ITEM}" | jq -r .resourceGroupName)

    echo "Working on virtual network $VNETNAME"

    # Checking if VNET is already created
	RESULT=$(az network vnet show -g "$VNETRG" -n "$VNETNAME")
	if [ "$RESULT"  == "" ]
	then
        echo "   Vnet $VNETNAME does not exist, creating a new one."

        # Getting other properties
        VNETLOC=$(echo "${ITEM}" | jq -r .location)
        VNETADDRESSSPACESCT=$(echo "${ITEM}" | jq -r '.addressSpaces | length')

        if [ "$VNETADDRESSSPACESCT" -eq 0 ]
        then
            echo "   No ip address range defined, skipping vnet."
            continue
        fi
        
        # Getting first address range and subnet
        ADDRESSSPACE=$(echo "${ITEM}" | jq -r '.addressSpaces[0].name')
        SUBNETNAME=$(echo "${ITEM}" | jq -r '.addressSpaces[0].subnets[0].name')
        SUBNETPREFIX=$(echo "${ITEM}" | jq -r '.addressSpaces[0].subnets[0].addressRange')

        # Creating vnet
        az network vnet create -n "$VNETNAME" -g "$VNETRG" -l "$VNETLOC" --address-prefix "$ADDRESSSPACE" --subnet-name $SUBNETNAME --subnet-prefix $SUBNETPREFIX

        # Updating ip address spaces
        echo "   Updating vnet ip address spaces with $ADDRESSSPACES"
        ADDRESSSPACES=$(echo "${ITEM}" | jq -j '.addressSpaces[].name + " "')
        az network vnet update -n "$VNETNAME" -g "$VNETRG" --address-prefixes $(trim "$ADDRESSSPACES")

        # Adding additional subnets per address space
        readarray -t ADDRESSSPACEARR < <( echo "${ITEM}" | jq -c '.addressSpaces[]')
        for ADDRESSSPACEARRITEM in "${ADDRESSSPACEARR[@]}"
        do
            SUBNETCT=$(echo "${ADDRESSSPACEARRITEM}" | jq -r '.subnets | length')

            if [ "$SUBNETCT" -gt 0 ]
            then
                SUBNETS=$(echo "${ADDRESSSPACEARRITEM}" | jq -r '.subnets')
                readarray -t SUBNETSARR < <( echo "$SUBNETS" | jq -c '.[]')

                for SUBNETITEM in "${SUBNETSARR[@]:0}"
                do
                    SUBNETNAME=$(echo "${SUBNETITEM}" | jq -r .name)
                    ADDRESSRANGE=$(echo "${SUBNETITEM}" | jq -r .addressRange)
                    NSG=$(echo "${SUBNETITEM}" | jq -r .networkSecurityGroup)
                    
                    echo "   Adding subnet $SUBNETNAME"
                    CMD="az network vnet subnet create -n \"$SUBNETNAME\" -g \"$VNETRG\" --vnet-name \"$VNETNAME\" --address-prefix \"$ADDRESSRANGE\""
                    if [ "$NSG" != "" ]
                    then
                        CMD="$CMD --network-security-group \"$NSG\""
                    fi

                    eval $CMD

                done
            fi
        done
	else
		echo "   Virtual Network  ${VNETNAME} already exists."
	fi
done

#--------------------------------------------
# Creating Virtual Networks
#-------------------------------------------- 
readarray -t PIPARR < <( echo $PIPS | jq -c '.[]')

for ITEM in "${PIPARR[@]}"
do
	PIPNAME=$(echo "${ITEM}" | jq -r .name)
	PIPLOC=$(echo "${ITEM}" | jq -r .location)
	PIPRG=$(echo "${ITEM}" | jq -r .resourceGroupName)
	PIPALLOC=$(echo "${ITEM}" | jq -r .allocationMethod)

    echo "Creating Public IP Address ${PIPNAME}."

	RESULT=$(az network public-ip show -n "$PIPNAME" -g "$PIPRG")
	if [ "$RESULT"  == "" ]
	then
	    az network public-ip create -g "$PIPRG" -l "$PIPLOC" -n "$PIPNAME" --allocation-method "$PIPALLOC"
	else
		echo "Public IP Address ${PIPNAME} already exists."
	fi
done

#--------------------------------------------
# Creating Linux Virtual Machines
#-------------------------------------------- 
readarray -t VMARR < <( echo $LINUXVMS | jq -c '.[]')

for ITEM in "${VMARR[@]}"
do
	VMSUBNET=$(echo "${ITEM}" | jq -r .subnet)
	VMVNET=$(echo "${ITEM}" | jq -r .virtualNetwork)
	VMADMINNAME=$(echo "${ITEM}" | jq -r .credential.adminUserName)
    VMADMINPWD=$(echo "${ITEM}" | jq -r .credential.adminPassword)
    VMNAME=$(echo "${ITEM}" | jq -r .name)
    VMIMAGE=$(echo "${ITEM}" | jq -r .vmImage)
    VMSTORAGEACCOUNT=$(echo "${ITEM}" | jq -r .storageAccount)
    VMLOC=$(echo "${ITEM}" | jq -r .location)
    VMSIZE=$(echo "${ITEM}" | jq -r .vmSize)
    VMRG=$(echo "${ITEM}" | jq -r .resourceGroupName)
    VMPIP=$(echo "${ITEM}" | jq -r .publicIpAddress)

    echo "Creating VM ${VMNAME}."

	RESULT=$(az vm show -n "$VMNAME" -g "$VMRG")
	if [ "$RESULT"  == "" ]
	then

        # Create NIC
        VMNICNAME="$VMNAME-NIC"
        echo "   Creating NIC $VMNICNAME"

        RESULT=$(az network nic show -n "$VMNICNAME" -g "$VMRG")
        if [ "$RESULT"  == "" ]
        then
            az network nic create -g "$VMRG" -l "$VMLOC" -n "$VMNICNAME" --subnet "$VMSUBNET" --vnet-name "$VMVNET" --public-ip-address "$VMPIP"
        else
            echo "NIC ${VMNICNAME} already exists."
        fi

        # Create VM
	    az vm create -n "$VMNAME" \
            -g "$VMRG" \
            -l "$VMLOC" \
            --image "$VMIMAGE" \
            --authentication-type password \
            --nics "$VMNICNAME" \
            --nsg '' \
            --admin-username "$VMADMINNAME" \
            --admin-password "$VMADMINPWD" \
            --storage-account "$VMSTORAGEACCOUNT" \
            --size "$VMSIZE" &
	else
		echo "VM ${VMNAME} already exists."
	fi
done
