#!/bin/bash
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the Apache License.

########################################################################
#
#   core_verify_lis_version
#
#   Description:
#       This script was created to automate the testing of a Linux
#   Integration services. The script will verify the list of given
#   LIS kernel modules and verify if the version matches with the 
#   Linux kernel release number.
#
#       To pass test parameters into test cases, the host will create
#   a file named constants.sh. This file contains one or more
#   variable definition.
#
########################################################################
# Source utils.sh
. utils.sh || {
    echo "ERROR: unable to source utils.sh!"
    echo "TestAborted" > state.txt
    exit 0
}

# Source constants file and initialize most common variables
UtilsInit

# Check if vmbus string is recorded in dmesg
hv_string=$(dmesg | grep "Vmbus version:")
if [[ ( $hv_string == "" ) || ! ( $hv_string == *"hv_vmbus:"*"Vmbus version:"* ) ]]; then
    LogErr "Error! Could not find the VMBus protocol string in dmesg."
    SetTestStateAborted
    exit 0
fi

skip_modules=()
vmbus_included=$(grep CONFIG_HYPERV=y /boot/config-$(uname -r))
if [ "$vmbus_included" ]; then
    skip_modules+=("hv_vmbus")
    LogMsg "Info: Skiping hv_vmbus module as it is built-in."
fi

storvsc_included=$(grep CONFIG_HYPERV_STORAGE=y /boot/config-$(uname -r))
if [ "$storvsc_included" ]; then
    skip_modules+=("hv_storvsc")
    LogMsg "Info: Skiping hv_storvsc module as it is built-in."
fi

# Remove each module in HYPERV_MODULES from skip_modules
for module in "${HYPERV_MODULES[@]}"; do
    skip=""
    for mod_skip in "${skip_modules[@]}"; do
        [[ $module == $mod_skip ]] && { skip=1; break; }
    done
    [[ -n $skip ]] || tempList+=("$module")
done
HYPERV_MODULES=("${tempList[@]}")

skipNext=true
temp_version=''
# Verifies first if the modules are loaded
for module in "${HYPERV_MODULES[@]}"; do
    load_status=$(lsmod | grep "$module" 2>&1)

    # Check to see if the module is loaded
    if [[ $load_status =~ $module ]]; then
        if rpm --help 2>/dev/null; then
            if rpm -qa | grep hyper-v 2>/dev/null; then
                version=$(modinfo "$module" | grep version: | head -1 | awk '{print $2}')
                LogMsg "$module module: ${version}"
                if [ "$skipNext" = true ] ; then
                    temp_version=$version
                    skipNext=false
                    continue
                fi
                if [ "$temp_version" != "$version" ] ;then
                    LogErr "ERROR: Status: $module $version doesnot match with build version $temp_version"
                    SetTestStateAborted
                    exit 0
                fi
                continue
            fi
        fi
        
        version=$(modinfo "$module" | grep vermagic: | awk '{print $2}')
        if [[ "$version" == "$(uname -r)" ]]; then
            LogMsg "Found a kernel matching version for $module module: ${version}"
        else
            LogErr "Error: LIS module $module doesn't match the kernel build version!"
            SetTestStateAborted
            exit 0
        fi
    fi
done

# Check to see if pci_hyperv module is getting loaded for RH7.x
if [[ $DISTRO_VERSION =~ 7\. ]]; then
    if rpm -qa | grep hyper-v 2>/dev/null; then
        pci_module=$(lsmod | grep pci_hyperv)
        if [ -z $pci_module ]; then
            modprobe pci_hyperv
            if [ 0 -ne $? ]; then
                LogErr "Unable to load pci_hyperv module!"
                SetTestStateAborted
                exit 0
            else
                pci_load_module=$(grep -rnw '/var/log' -e "hv_vmbus: registering driver hv_pci" --ignore-case)
                if [ -z $pci_load_module ]; then
                    LogErr  "ERROR: Status: pci_hyperv is not loaded"
                    SetTestStateAborted
                    exit 0
                else
                    LogMsg  "Status: pci_hyperv loaded!"
                    version=$(modinfo pci_hyperv | grep version: | head -1 | awk '{print $2}')
                    LogMsg "pci_hyperv module: ${version}"
                    if [ "$temp_version" != "$version" ] ;then
                        LogErr "ERROR: Status: pci_hyperv $version doesnot match with build version $temp_version"
                        SetTestStateAborted
                        exit 0
                    fi
                fi
            fi
        else
            LogMsg  "Status: pci_hyperv loaded!"
            version=$(modinfo pci_hyperv | grep version: | head -1 | awk '{print $2}')
            LogMsg "pci_hyperv module: ${version}"
            if [ "$temp_version" != "$version" ] ;then
                LogErr "ERROR: Status: pci_hyperv $version doesnot match with build version $temp_version"
                SetTestStateAborted
                exit 0
            fi
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
                LogErr  "ERROR: Status: mlx4_en is not loaded"
                SetTestStateAborted
                exit 0
            else
                LogMsg  "Status: mlx4_en loaded!"
                version=$(modinfo mlx4_en | grep version: | head -1 | awk '{print $2}')
                LogMsg "mlx4_en module: ${version}"
                if [ "$MLNX_VERSION" != "$version" ] ;then
                    LogErr "ERROR: Status: mlx4_en $version doesnot match with build version $MLNX_VERSION"
                    SetTestStateAborted
                    exit 0
                fi
            fi
        else
            LogMsg  "Status: mlx4_en loaded!"
            version=$(modinfo mlx4_en | grep version: | head -1 | awk '{print $2}')
            LogMsg "mlx4_en module: ${version}"
            if [ "$MLNX_VERSION" != "$version" ] ;then
                LogErr "ERROR: Status: mlx4_en $version doesnot match with build version $MLNX_VERSION"
                SetTestStateAborted
                exit 0
            fi
        fi
    fi
fi

SetTestStateCompleted
exit 0
