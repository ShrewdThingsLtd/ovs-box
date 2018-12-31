#!/bin/bash

ovs_dpdk_add_br() {

	local ovs_br=$1
	
	exec_log "ovs-vsctl add-br ${ovs_br} -- set bridge ${ovs_br} datapath_type=netdev"
}

ovs_dpdk_add_dummy_port() {

	local ovs_br=$1
	local port_name=$2
	
	modprobe dummy
	ip link delete ${port_name} type dummy
	ip link add ${port_name} type dummy
	ip link set ${port_name} up
	exec_log "ovs-vsctl add-port ${ovs_br} ${port_name}"
}

ovs_dpdk_add_dpdk_port() {

	local ovs_br=$1
	local port_name=$2
	local pci_addr=$3
	
	exec_log "ovs-vsctl add-port ${ovs_br} ${port_name} -- set Interface ${port_name} type=dpdk options:dpdk-devargs=${pci_addr}"
}

ovs_dpdk_add_flow() {

	local ovs_br=$1
	local flow_pattern=$2
	shift 2
	local flow_expr=$(printf "${flow_pattern}" $@)
	
	exec_log "ovs-ofctl -O OpenFlow13 add-flow ${ovs_br} ${flow_expr}"
}

ovs_dpdk() {

	local cmd=$1
	shift

	case ${cmd} in
		'add-br')
		ovs_dpdk_add_br $@
		;;
		'add-dummy-port')
		ovs_dpdk_add_dummy_port $@
		;;
		'add-dpdk-port')
		ovs_dpdk_add_dpdk_port $@
		;;
		'add-flow')
		ovs_dpdk_add_flow $@
		;;
		*)
		exec_log "ovs-vsctl ${cmd} $@"
		;;
	esac
}
