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
ovs_dpdk_docker() {

	local remote_dir="/"
##################
local ovs_docker_cmd="/tmp/${DOCKER_INST}/ovs-docker $@"
local ovs_vsctl_cmd=$(printf '
#!/bin/bash\n
exec_cmd="ovs-vsctl $@"\n
docker exec %s /bin/bash -c "${exec_cmd}"\n
' ${DOCKER_INST})
local remote_cmd="\
export DOCKER_INST=${DOCKER_INST};\
mkdir -p /tmp/${DOCKER_INST};\
echo \"${ovs_vsctl_cmd}\" > /tmp/${DOCKER_INST}/ovs-vsctl.sh;\
docker cp ${DOCKER_INST}:/usr/local/bin/ovs-docker /tmp/${DOCKER_INST}/ovs-docker;\
mv -f /usr/local/bin/ovs-vsctl /tmp/${DOCKER_INST}/ovs-vsctl.backup;\
mv -f /tmp/${DOCKER_INST}/ovs-vsctl.sh /usr/local/bin/ovs-vsctl;\
chmod +x /usr/local/bin/ovs-vsctl;\
chmod +x /tmp/${DOCKER_INST}/ovs-docker;\
${ovs_docker_cmd};\
rm -f /usr/local/bin/ovs-vsctl;\
mv -f /tmp/${DOCKER_INST}/ovs-vsctl.backup /usr/local/bin/ovs-vsctl;\
##################
	exec_tgt "${remote_dir}" "${remote_cmd}"
}

ovs_dpdk_docker() {

	local remote_dir="/"
##################
local ovs_docker_cmd="/tmp/${DOCKER_INST}/ovs-docker $@"
local remote_cmd="\
mkdir -p /tmp/${DOCKER_INST};\
echo '#!/bin/bash' > /tmp/${DOCKER_INST}/ovs-vsctl.sh;\
echo 'docker exec ${DOCKER_INST} ovs-vsctl $@' >> /tmp/${DOCKER_INST}/ovs-vsctl.sh;\
docker cp ${DOCKER_INST}:/usr/local/bin/ovs-docker /tmp/${DOCKER_INST}/ovs-docker;\
mv /usr/local/bin/ovs-vsctl /tmp/${DOCKER_INST}/ovs-vsctl.backup;\
mv /tmp/${DOCKER_INST}/ovs-vsctl.sh /usr/local/bin/ovs-vsctl;\
chmod +x /usr/local/bin/ovs-vsctl;\
${ovs_docker_cmd};\
rm /usr/local/bin/ovs-vsctl;\
mv /tmp/${DOCKER_INST}/ovs-vsctl.backup /usr/local/bin/ovs-vsctl"
##################
	exec_tgt "${remote_dir}" "${remote_cmd}"
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
		'del-br')
		ovs_dpdk_del_br $@
		;;
		'add-dummy-port')
		ovs_dpdk_add_dummy_port $@
		;;
		'add-docker-port')
		ovs_dpdk_docker add-port $@
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
