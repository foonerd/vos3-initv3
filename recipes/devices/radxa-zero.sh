#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Radxa Zero (Amlogic S905Y2)
DEVICE_SUPPORT_TYPE="C" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="P"       # First letter (Planned|Test|Maintenance)

# shellcheck source=./recipes/devices/families/radxa-0.sh
source "${SRC}"/recipes/devices/families/radxa-0.sh

### Device information
DEVICENAME="Radxa Zero"
DEVICE="radxa-zero"



