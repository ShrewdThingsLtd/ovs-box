#!/bin/bash

ovs_dpdk_add_dpdk_br() {

	local ovs_br=$1
	
	exec_log "ovs_cmd add-br ${ovs_br} -- set bridge ${ovs_br} datapath_type=netdev"
}

ovs_dpdk_add_br() {

	local ovs_br=$1
	
	exec_log "ovs_cmd add-br ${ovs_br}"
}

ovs_dpdk_add_dummy_port() {

	local ovs_br=$1
	local port_name=$2
	
	modprobe dummy
	ip link delete ${port_name} type dummy
	ip link add ${port_name} type dummy
	ip link set ${port_name} up
	exec_log "ovs_cmd add-port ${ovs_br} ${port_name}"
}

ovs_dpdk_set_port_id() {

	set +x
	local dev_name=$1
	local port_id=$2

	ovs_cmd set interface ${dev_name} ofport_request=${port_id}
	set +x
}

ovs_dpdk_docker_set_port_id() {

	set +x
	local container_name=$1
	local container_dev_name=$2
	local port_id=$3

	local container_ifidx=$(exec_tgt '/' "docker exec ${container_name} cat /sys/class/net/${container_dev_name}/iflink")
	#container_ifidx=$(grep -oh "[0-9]*" <<< ${container_ifidx})
	local host_ifidx=$((container_ifidx - 1))
	local docker_peer_dev=$(grep ${host_ifidx} /sys/class/net/*/iflink | sed "s~/sys/class/net/\(.*\)/iflink\:[0-9]*$~\1~")
	ovs_cmd set interface ${docker_peer_dev} ofport_request=${port_id}
	set +x
}

ovs_dpdk_docker() {

	echo "ovs_dpdk_docker"
	set +x
	local remote_dir="/"
##################
local ovs_docker_cmd="/tmp/${DOCKER_INST}/ovs-docker $@"
local remote_script="\
export DOCKER_INST=${DOCKER_INST};\
mkdir -p /tmp/${DOCKER_INST};\
docker cp ${DOCKER_INST}:/usr/local/bin/ovs-vsctl-remote.sh /tmp/${DOCKER_INST}/ovs-vsctl-remote.sh;\
docker cp ${DOCKER_INST}:/usr/local/bin/ovs-docker /tmp/${DOCKER_INST}/ovs-docker;\
mv -f /usr/local/bin/ovs-vsctl /tmp/${DOCKER_INST}/ovs-vsctl.backup;\
mv -f /tmp/${DOCKER_INST}/ovs-vsctl-remote.sh /usr/local/bin/ovs-vsctl;\
chmod +x /usr/local/bin/ovs-vsctl;\
chmod +x /tmp/${DOCKER_INST}/ovs-docker;\
${ovs_docker_cmd};\
rm -f /usr/local/bin/ovs-vsctl;\
mv -f /tmp/${DOCKER_INST}/ovs-vsctl.backup /usr/local/bin/ovs-vsctl;\
"
local remote_cmd="echo \"${remote_script}\" > /tmp/${DOCKER_INST}/exec_cmd.sh; chmod +x /tmp/${DOCKER_INST}/exec_cmd.sh; /tmp/${DOCKER_INST}/exec_cmd.sh"
##################
	exec_tgt "${remote_dir}" "${remote_cmd}"
	set +x
}

ovs_dpdk_add_dpdk_port() {

	local ovs_br=$1
	local port_name=$2
	local pci_addr=$3
	
	exec_log "ovs_cmd add-port ${ovs_br} ${port_name} -- set Interface ${port_name} type=dpdk options:dpdk-devargs=${pci_addr}"
}

ovs_dpdk_add_port() {

	local ovs_br=$1
	local port_name=$2
	
	exec_log "ovs_cmd add-port ${ovs_br} ${port_name}"
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
		'add-dpdk-br')
		ovs_dpdk_add_dpdk_br $@
		;;
		'add-br')
		ovs_dpdk_add_br $@
		;;
		'del-br')
		ovs_dpdk_del_br $@
		;;
		'add-dummy-port')
		ovs_dpdk_add_dummy_port $@
		;;
		'add-docker-port')
		ovs_dpdk_docker add-port $@
		;;
		'del-docker-port')
		ovs_dpdk_docker del-port $@
		;;
		'set-port-id')
		ovs_dpdk_set_port_id $@
		;;
		'set-docker-port-id')
		ovs_dpdk_docker_set_port_id $@
		;;
		'add-dpdk-port')
		ovs_dpdk_add_dpdk_port $@
		;;
		'add-port')
		ovs_dpdk_add_port $@
		;;
		'add-flow')
		ovs_dpdk_add_flow $@
		;;
		*)
		exec_log "ovs_cmd ${cmd} $@"
		;;
	esac
}
