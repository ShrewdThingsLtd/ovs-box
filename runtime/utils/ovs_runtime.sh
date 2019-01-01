#!/bin/bash

set -x

ovs_mount_hugepages() {

	sysctl -w vm.nr_hugepages=$OVS_2M_HUGEPAGES
	mkdir -p /mnt/huge
	#mount -t hugetlbfs -o pagesize=1G nodev /mnt/huge
	mount -t hugetlbfs nodev /mnt/huge
	grep HugePages_ /proc/meminfo
}

ovsdb_reset() {

	mkdir -p $OVS_ETC_DIR
	mkdir -p $OVS_LOG_DIR
	mkdir -p $OVS_RUNTIME_DIR
	rm -f $OVS_ETC_DIR/conf.db
	ovsdb-tool create $OVS_ETC_DIR/conf.db $OVS_SHARE_DIR/vswitch.ovsschema
	ovs-vsctl --no-wait init
}

ovs_cmd() {

	local ovs_exec="ovs-vsctl $OVS_MODIFIERS ${@:1}"
	eval "${ovs_exec}"
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

ovsdb_server_start() {

	ovsdb-server \
		--remote=punix:$OVS_RUNTIME_DIR/db.sock \
		--remote=db:Open_vSwitch,Open_vSwitch,manager_options \
		--pidfile --detach --log-file
	ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
}

ovs_restart() {

	ovs-ctl --no-ovsdb-server --db-sock="$OVS_RUNTIME_DIR/db.sock" restart
	ovs-vsctl get Open_vSwitch . dpdk_initialized
	ovs-vswitchd --version
	ovs-vsctl get Open_vSwitch . dpdk_version
	ovs-ctl status
}

ovs_run() {

	exec_tgt "/" "modprobe openvswitch"
	ovs_wipeout
	ovs_mount_hugepages
	ovsdb_server_start
	ovs_restart
}

set +x
