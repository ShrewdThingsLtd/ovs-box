#!/bin/bash

set +x

ovs_cmd_create() {

local ovs_install_dir=/usr/local/bin
local ovs_backup_dir=/usr/local/bin/backup
local ovs_build_dir=/usr/src/ovs/utilities
printf '
#!/bin/bash\n
ovs_exec="%s/ovs-vsctl %s --db=unix:%s ${@}"\n
eval "${ovs_exec}"\n' \
	${ovs_build_dir} \
	"${OVS_MODIFIERS}" \
	"${OVS_RUNTIME_DIR}/db.sock" \
	> /usr/local/bin/ovs_cmd
chmod +x /usr/local/bin/ovs_cmd
mkdir -p ${ovs_backup_dir}
mv -f ${ovs_install_dir}/ovs-vsctl ${ovs_backup_dir}/ovs-vsctl
cp -f ${ovs_install_dir}/ovs_cmd ${ovs_install_dir}/ovs-vsctl
}

ovs_vsctl_remote_create() {

printf '
#!/bin/bash\n
exec_cmd="docker exec %s /bin/bash -c '"'"'ovs_cmd ${@}'"'"'"\n
eval "${exec_cmd}"\n' \
	${DOCKER_INST} \
	> /usr/local/bin/ovs-vsctl-remote.sh
chmod +x /usr/local/bin/ovs-vsctl-remote.sh
}

ovs_mount_hugepages() {

	sysctl -w vm.nr_hugepages=$OVS_2M_HUGEPAGES
	mkdir -p /mnt/huge
	#mount -t hugetlbfs -o pagesize=1G nodev /mnt/huge
	mount -t hugetlbfs nodev /mnt/huge
}

ovsdb_reset() {

	mkdir -p $OVS_ETC_DIR
	mkdir -p $OVS_LOG_DIR
	mkdir -p $OVS_RUNTIME_DIR
	rm -f $OVS_ETC_DIR/conf.db
	ovsdb-tool \
		create $OVS_ETC_DIR/conf.db $OVS_SHARE_DIR/vswitch.ovsschema
	ovs_cmd --no-wait init
}

ovs_clear_br() {

	local br_inst=$1

	echo ".........................."
	echo "Deleting OF flows"
	ovs-ofctl del-flows ${br_inst}
	ports_list=$(ovs_cmd list-ports ${br_inst})
	for port_inst in ${ports_list}; do
		echo "............................"
		echo "Removing port from bridge:  [${br_inst}]-X   X/${port_inst}/"
		pci_addr=$(ovs_cmd get Interface ${port_inst} options:dpdk-devargs)
		ovs_cmd del-port ${port_inst}
		if [[ "${pci_addr}" != "" ]]
			then
			echo "........................................."
			echo "Detaching PCI (possible benign error):   [${br_inst}]-X   X${pci_addr}"
			echo ${pci_addr} | xargs ovs-appctl netdev-dpdk/detach
		fi
	done
}

ovs_dpdk_del_br() {

	local br_inst=$1

	if [[ -z ${br_inst} ]]
	then
		local br_list=$(ovs_cmd list-br)
		for br_inst in ${br_list}; do
			ovs_clear_br ${br_inst}
		done
		echo ".........................."
		echo "Deleting QoS"
		ovs_cmd -- --all destroy QoS -- --all destroy Queue
		echo ".........................."
		echo "Deleting bridges:         $(echo ${br_list})"
		for br_inst in ${br_list}; do
			ovs_cmd del-br ${br_inst}
			ip link delete ${br_inst}
		done
		echo "========================================================================="
		echo "DONE CLEARING OVS"
		echo "========================================================================="
		echo "========================================================================="
		echo
		rm -f $(pwd)/.ovs_ulog.log
	else
		ovs_clear_br ${br_inst}
		ovs_cmd del-br ${br_inst}
		ip link delete ${br_inst}
	fi
}

ovs_wipeout() {

	ovs_dpdk_del_br
	ovs-ctl stop
	ovsdb_reset
}

ovsdb_server_kernel_start() {

	ovsdb-server \
		--log-file -v \
		--remote=punix:$OVS_RUNTIME_DIR/db.sock \
		--remote=db:Open_vSwitch,Open_vSwitch,manager_options \
		--pidfile=$OVS_RUNTIME_DIR/ovsdb-server.pid --detach
	ovs_cmd  --no-wait set Open_vSwitch . external_ids:hostname=${DOCKER_INST}.inst
}

ovsdb_server_start() {

	ovsdb-server \
		--log-file -v \
		--remote=punix:$OVS_RUNTIME_DIR/db.sock \
		--remote=db:Open_vSwitch,Open_vSwitch,manager_options \
		--pidfile=$OVS_RUNTIME_DIR/ovsdb-server.pid --detach
	ovs_cmd  --no-wait set Open_vSwitch . external_ids:hostname=${DOCKER_INST}.inst
	ovs_cmd --no-wait set Open_vSwitch . other_config:dpdk-init=true
}

ovs_kernel_restart() {

	ovs-ctl --no-ovsdb-server --db-sock="$OVS_RUNTIME_DIR/db.sock" restart
	ovs-vswitchd \
		--pidfile=$OVS_RUNTIME_DIR/ovs-vswitchd.pid \
		--log-file -v \
		--version
	ovs-ctl status
}

ovs_restart() {

	ovs-ctl --no-ovsdb-server --db-sock="$OVS_RUNTIME_DIR/db.sock" restart
	ovs_cmd get Open_vSwitch . dpdk_initialized
	ovs-vswitchd \
		--pidfile=$OVS_RUNTIME_DIR/ovs-vswitchd.pid \
		--log-file -v \
		--version
	ovs_cmd get Open_vSwitch . dpdk_version
	ovs-ctl status
}

ovs_run() {

	ovs_cmd_create
	ovs_vsctl_remote_create
	#dpdk_remote_install
	ovs_mount_hugepages
	grep HugePages_ /proc/meminfo
	ovsdb_reset
	exec_tgt "/" "modprobe openvswitch"
	ovsdb_server_start
	ovs_restart
}

set +x
