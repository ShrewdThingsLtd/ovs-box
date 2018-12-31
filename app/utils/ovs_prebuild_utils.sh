#!/bin/bash

set -x

ovs_prerequisites() {

	echo 'autoconf automake libtool openssl libssl-dev python libpcap-dev libcap-ng-dev python-six libfuse-dev iproute2 kmod sudo'
}

ovs_clone() {

	git_clone $SRC_DIR $OVS_REPO $OVS_VERSION
}

ovs_pull() {

	git_pull "${OVS_DIR}" "${OVS_VERSION}"
}

ovs_dpdk_config() {

	sed -i s/CONFIG_RTE_BUILD_COMBINE_LIBS=n/CONFIG_RTE_BUILD_COMBINE_LIBS=y/ $DPDK_DIR/config/common_linuxapp
	sed -i s/CONFIG_RTE_LIBRTE_VHOST=n/CONFIG_RTE_LIBRTE_VHOST=y/ $DPDK_DIR/config/common_linuxapp
	sed -i s/CONFIG_RTE_LIBRTE_VHOST_USER=y/CONFIG_RTE_LIBRTE_VHOST_USER=n/ $DPDK_DIR/config/common_linuxapp
}

ovs_build() {

	cd "${OVS_DIR}"
	./boot.sh
	./configure --with-dpdk=${DPDK_DIR}/${DPDK_TARGET}
	make install CFLAGS='-O3 -march=native'
	#make clean
	cd -
}

dpdk_configure() {

	exec_apt_install "$(ovs_prerequisites)"
	#exec_apt_clean
	ovs_dpdk_config
}

set +x

