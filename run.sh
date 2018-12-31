#!/bin/bash

IMG_DOMAIN=${2:-local}
DPDK_VERSION=${1:-v17.11-rc4}
OVS_VERSION=${3:-v2.10.1}

docker volume rm $(docker volume ls -qf dangling=true)
#docker network rm $(docker network ls | grep "bridge" | awk '/ / { print $1 }')
docker rmi $(docker images --filter "dangling=true" -q --no-trunc)
docker rmi $(docker images | grep "none" | awk '/ / { print $3 }')
docker rm $(docker ps -qa --no-trunc --filter "status=exited")

case ${IMG_DOMAIN} in
	"hub")
	IMG_TAG=shrewdthingsltd/ovs-box:$OVS_VERSION
	docker pull $IMG_TAG
	;;
	*)
	IMG_TAG=local/ovs-box:$OVS_VERSION
	DPDK_IMG=local/dpdk-box:$DPDK_VERSION
	OVS_REPO="https://github.com/openvswitch/ovs.git"
	docker build \
		-t $IMG_TAG \
		--build-arg IMG_BASE=$DPDK_IMG \
		--build-arg IMG_OVS_REPO=$OVS_REPO \
		--build-arg IMG_OVS_VERSION=$OVS_VERSION \
		./
	;;
esac

docker run \
	-ti \
	--net=host \
	--privileged \
	-v /mnt/huge:/mnt/huge \
	--device=/dev/uio0:/dev/uio0 \
	$IMG_TAG \
	/bin/bash
