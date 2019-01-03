#!/bin/bash

export OVS_RUNTIME_DIR=/usr/local/var/run/openvswitch
export OVS_SHARE_DIR=/usr/local/share/openvswitch
export OVS_ETC_DIR=/usr/local/etc/openvswitch
export OVS_LOG_DIR=/usr/local/var/log/openvswitch
export OVS_2M_HUGEPAGES=2048
export PATH=$PATH:$OVS_SHARE_DIR/scripts
