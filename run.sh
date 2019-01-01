#!/bin/bash

IMG_DOMAIN=${1:-local}
DPDK_VERSION=${2:-v17.11-rc4}
OVS_VERSION=${3:-v2.10.1}
DOCKER_INST=${4:-ovs-box}

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
		./
	;;
esac

docker kill $DOCKER_INST
docker rm $DOCKER_INST
docker run \
	-ti \
	--net=host \
	--privileged \
	-v /mnt/huge:/mnt/huge \
	--device=/dev/uio0:/dev/uio0 \
	--name=$DOCKER_INST \
	--env DOCKER_INST=$DOCKER_INST \
	$IMG_TAG \
	/bin/bash
