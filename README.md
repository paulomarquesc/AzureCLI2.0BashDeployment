# azuredeploy.sh

This script is an end to end example on how to make deployments on Azure using Azure CLI 2.0 on top of bash. It's counterpart for comparison based on PowerShell can be found at https://gallery.technet.microsoft.com/Azure-Resource-Manager-6514f9ca?redir=0. 

This script requires JQ installed on Linux and Azure CLI 2.0.

## Installing Azure CLI 2.0 on Bash on Ubuntu on Windows
Azure CLI 2.0 is a new version of Azure Xplat CLI, it is used to manage Azure through command line in Windows, Linux and OS X.

* Updating Python to the latest version (minimum supported is 2.7.6)
* Install other dependencies

  ```
  sudo apt-get update && sudo apt-get install -y libssl-dev libffi-dev python-dev
  ```
  
* Install Azure CLI 2.0

  ```
  sudo su
  curl -L https://aka.ms/InstallAzureCli | bash
  ```
  
  * When asked type the following answers:
  
    ```
    /usr/lib/azure-cli
    /usr/bin
    y
    /etc/bash.bashrc
    ```
    
* Exit bash and open it again

## Installing Azure CLI 2.0 on Ubuntu 16.10

* These steps assumes you installed a VM in Azure from Ubuntu 16.10 marketplace image, perform upgrade on existing packages

  ```
  sudo apt-get update
  sudo apt-get upgrade -y
  ```
  
* Install dependencies

  ```
  sudo apt-get update && sudo apt-get install -y libssl-dev libffi-dev python-dev build-essential
  sudo su
  curl -L https://aka.ms/InstallAzureCli | bash
  ```

* When asked type the following answers:
  
    ```
    /usr/lib/azure-cli    
    /usr/bin
    y
    /etc/bash.bashrc
    ```
    
* Logoff of this session and open session again

For more information about Azure CLI 2.0 please refer to https://docs.microsoft.com/en-us/cli/azure/overview.

## Installing JQ 
jq is a json command-line json processor which helps querying (it also transforms) json strings to extract information.

* On Bash on Ubuntu on Windows 10 prompt execute the following steps:

  * Install dependencies
  
    ```
    sudo apt-get install build-essential libtool autoconf gcc –y
    ```

  * Download and extract oniguruma and jq sources
    
    curl -L https://github.com/kkos/oniguruma/releases/download/v5.9.6_p1/onig-5.9.6_p1.tar.gz -o ./onig-5.9.6_p1.tar.gz
    curl -L https://github.com/stedolan/jq/releases/download/jq-1.5/jq-1.5.tar.gz -o jq-1.5.tar.gz
    tar -xvzf ./onig-5.9.6_p1.tar.gz
    tar -xvzf ./jq-1.5.tar.gz

  * Install oniguruma
  
    ```  
    cd onig-5.9.6
    ./configure && make && sudo make install
    ```

  * Install jq

    ```
    cd jq-1.5
    ./configure && make && sudo make install
    ```

* To install on full Ubuntu 16.10 execute the following:
  
  ```
  sudo apt-get install jq -y
  ```