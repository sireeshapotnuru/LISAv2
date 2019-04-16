#!/bin/bash
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the Apache License.

PASS="0"
# Source utils.sh
. utils.sh || {
    echo "ERROR: unable to source utils.sh!"
    echo "TestAborted" > state.txt
    exit 2
}

# Source constants file and initialize most common variables
UtilsInit

### Display info on the Hyper-V modules that are loaded ###
LogMsg "#### Status of Hyper-V Kernel Modules ####"

#Check if VMBus module exist and if exist continue checking the other modules
hv_string=$(dmesg | grep "Vmbus version:")
if [[ ( $hv_string == "" ) || ! ( $hv_string == *"hv_vmbus:"*"Vmbus version:"* ) ]]; then
    LogMsg "Error! Could not find the VMBus protocol string in dmesg."
    LogMsg "Exiting with state: TestAborted."
    SetTestStateAborted
    exit 0
fi

# Check to see if each module is loaded.
for module in "${HYPERV_MODULES[@]}"; do
    LogMsg "Module: $module"
    load_module=$(grep -rnw '/var/log' -e "hv_vmbus: registering driver $module" --ignore-case)
    if [ -z $load_module == "" ]; then
        LogMsg "ERROR: Status: $module is not loaded"
        PASS="1"
    else
        LogMsg "$load_module"
        LogMsg "Status: $module loaded!"
    fi
    echo -ne "\\n\\n"
done

# Check to see if pci_hyperv module is getting loaded for RH7.x
if [[ $DISTRO_VERSION =~ 7\. ]]; then
    if rpm -qa | grep hyper-v 2>/dev/null; then
        pci_module=$(lsmod | grep pci_hyperv)
        if [ -z $pci_module ]; then
            modprobe pci_hyperv
            if [ 0 -ne $? ]; then
                LogMsg "Unable to load pci_hyperv module!"
                PASS="1"
            else
                pci_load_module=$(grep -rnw '/var/log' -e "hv_vmbus: registering driver hv_pci" --ignore-case)
                if [ -z $pci_load_module ]; then
                    LogMsg  "ERROR: Status: pci_hyperv is not loaded"
                    PASS="1"
                else
                    LogMsg  "Status: pci_hyperv loaded!"
                fi
            fi
        else
            LogMsg  "Status: pci_hyperv loaded!"
        fi
    fi
fi

# Check to see if mlx4 is getting loaded for RH7.3 and RH7.4
if [[ $DISTRO_VERSION =~ 7\.3 ]] || [[ $DISTRO_VERSION =~ 7\.4 ]] ; then
    if rpm -qa | grep hyper-v 2>/dev/null; then
        mlx4_module=$(lsmod | grep mlx4_en)
        if [ -z $mlx4_module ]; then
            modprobe mlx4_en
            lsmod | grep mlx4_en
            if [ 0 -ne $? ]; then
                LogMsg  "ERROR: Status: mlx4_en is not loaded"
                PASS="1"
            else
                LogMsg  "Status: mlx4_en loaded!"
            fi
        else
            LogMsg  "Status: mlx4_en loaded!"
        fi
    fi
fi
#
# Let the caller know everything worked
#
if [ "1" -eq "$PASS" ]; then
    LogMsg "Exiting with state: TestAborted."
    SetTestStateAborted
else 
    LogMsg "Exiting with state: TestCompleted."
    SetTestStateCompleted
    exit 0
fi
