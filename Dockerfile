FROM golang:1.15-buster as builder

ARG VERSION
ARG GOARCH
ARG QEMU_ARCH

RUN apt-get update && \
	apt-get install make git bash gcc && \
	mkdir -p $GOPATH/src/github.com/google && \
	git clone https://github.com/google/cadvisor.git $GOPATH/src/github.com/google/cadvisor

WORKDIR $GOPATH/src/github.com/google/cadvisor

RUN git fetch --tags && \
	git checkout $VERSION && \
	make build GOARCH=$GOARCH && \
	cp ./cadvisor /

ARG CONTAINER

FROM $CONTAINER

COPY qemu-${QEMU_ARCH}-static /usr/bin

RUN apk --no-cache add libc6-compat device-mapper findutils && \
    apk --no-cache add zfs || true && \
    apk --no-cache add thin-provisioning-tools --repository http://dl-3.alpinelinux.org/alpine/edge/main/ && \
    echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf && \
    rm -rf /var/cache/apk/* && \
    rm -rf /usr/bin/qemu-${QEMU_ARCH}-static

COPY --from=builder /cadvisor /usr/bin/cadvisor

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --quiet --tries=1 --spider http://localhost:8080/healthz || exit 1

ENTRYPOINT [ "/usr/bin/cadvisor", "-logstostderr" ]
