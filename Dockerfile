
ARG IMG_BASE=shrewdthingsltd/dpdk-box:v17.11-rc4

FROM $IMG_BASE

ARG IMG_OVS_REPO="https://github.com/openvswitch/ovs.git"
ARG IMG_OVS_VERSION="v2.10.1"

ENV OVS_REPO="${IMG_OVS_REPO}"
ENV OVS_VERSION=$IMG_OVS_VERSION
ENV OVS_DIR=${SRC_DIR}/ovs

COPY app/ ${SRC_DIR}/
ENV BASH_ENV=${SRC_DIR}/docker-entrypoint.sh

RUN ovs_clone
RUN ovs_build

COPY runtime/ ${SRC_DIR}/runtime/
ENV BASH_ENV=${SRC_DIR}/app-entrypoint.sh

WORKDIR ${OVS_DIR}
