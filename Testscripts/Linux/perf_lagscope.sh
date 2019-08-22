#!/bin/bash

#######################################################################
#
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the Apache License.
# 
#######################################################################

#######################################################################
#
# perf_lagscope.sh
# Description:
#    Download and run lagscope latency tests.
#    This script needs to be run on client VM.
#
# Supported Distros:
#    Ubuntu 16.04
#######################################################################

CONSTANTS_FILE="./constants.sh"
UTIL_FILE="./utils.sh"
ICA_TESTCOMPLETED="TestCompleted"	# The test completed successfully
ICA_TESTABORTED="TestAborted"		# Error during the setup of the test
touch ./lagscopeTest.log

LogMsg()
{
	echo $(date "+%b %d %Y %T") : "${1}"    # Add the time stamp to the log message
	echo "${1}" >> ./lagscopeTest.log
}

UpdateTestState()
{
	echo "${1}" > ./state.txt
}

. ${CONSTANTS_FILE} || {
	errMsg="Error: missing ${CONSTANTS_FILE} file"
	LogMsg "${errMsg}"
	UpdateTestState $ICA_TESTABORTED
	exit 10
}
. ${UTIL_FILE} || {
	errMsg="Error: missing ${UTIL_FILE} file"
	LogMsg "${errMsg}"
	UpdateTestState $ICA_TESTABORTED
	exit 10
}

if [ ! "${server}" ]; then
	errMsg="Please add/provide value for server in constants.sh. server=<server ip>"
	LogMsg "${errMsg}"
	echo "${errMsg}" >> ./summary.log
	UpdateTestState $ICA_TESTABORTED
	exit 1
fi
if [ ! "${client}" ]; then
	errMsg="Please add/provide value for client in constants.sh. client=<client ip>"
	LogMsg "${errMsg}"
	echo "${errMsg}" >> ./summary.log
	UpdateTestState $ICA_TESTABORTED
	exit 1
fi

if [ ! "${pingIteration}" ]; then
	errMsg="Please add/provide value for pingIteration in constants.sh. pingIteration=1000000"
	LogMsg "${errMsg}"
	echo "${errMsg}" >> ./summary.log
	UpdateTestState $ICA_TESTABORTED
	exit 1
fi

#Make & build lagscope on client and server VMs

LogMsg "Configuring client ${client}..."
ssh "${client}" ". $UTIL_FILE && install_lagscope ${lagscopeVersion}"
if [ $? -ne 0 ]; then
	LogMsg "Error: lagscope installation failed in ${client}.."
	UpdateTestState "TestAborted"
	exit 1
fi

LogMsg "Configuring server ${server}..."
ssh "${server}" ". $UTIL_FILE && install_lagscope ${lagscopeVersion}"
if [ $? -ne 0 ]; then
	LogMsg "Error: lagscope installation failed in ${server}.."
	UpdateTestState "TestAborted"
	exit 1
fi

if [[ $(detect_linux_distribution) == coreos ]]; then
	cmd="docker run --network host lisms/lagscope"
	ssh root@"${server}" ". $UTIL_FILE && Delete_Containers"
	ssh root@"${client}" ". $UTIL_FILE && Delete_Containers"
else
	cmd="lagscope"
fi

#Now, start lagscope on server and client VMs.

LogMsg "Now running Lagscope test"
LogMsg "Starting server."
ssh root@"${server}" "${cmd} -r" &
sleep 20
LogMsg "lagscope client running..."
ssh root@"${client}" "${cmd} -s${server} -i0 -n${pingIteration} -H > lagscope-n${pingIteration}-output.txt"
LogMsg "Test finished."
UpdateTestState $ICA_TESTCOMPLETED
