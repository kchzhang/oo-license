ARG product_version=8.3.3
ARG build_number=18
ARG oo_root='/var/www/onlyoffice/documentserver'

## Setup

FROM onlyoffice/documentserver:${product_version} as setup-stage
ARG product_version
ARG build_number
ARG oo_root
ENV PRODUCT_VERSION=${product_version}
ENV BUILD_NUMBER=${build_number}


ARG build_deps="git make g++ nodejs bzip2"
RUN apt-get update  
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash -
RUN apt update
RUN apt-get install -y ${build_deps}
RUN npm install -g pkg grunt grunt-cli


## Clone

FROM setup-stage as clone-stage
ARG tag=v${PRODUCT_VERSION}.${BUILD_NUMBER}
RUN git clone --quiet --branch $tag --depth 1 https://github.com/ONLYOFFICE/build_tools.git /build/build_tools
RUN git clone --quiet --branch $tag --depth 1 https://github.com/ONLYOFFICE/server.git      /build/server

COPY server/Makefile /build/server
COPY server/package.json /build/server
COPY server/license.js /build/server/Common/sources
COPY server/constants.js /build/server/Common/sources
COPY server/FileConverter/package.json /build/server/FileConverter
COPY server/DocService/package.json /build/server/DocService


# COPY server.patch /build/server.patch
# RUN cd /build/server   && git apply /build/server.patch

## Build
FROM clone-stage as build-stage
WORKDIR /build/server
RUN make
RUN pkg /build/build_tools/out/linux_64/onlyoffice/documentserver/server/FileConverter --targets=node16-linux -o /build/converter
RUN pkg /build/build_tools/out/linux_64/onlyoffice/documentserver/server/DocService --targets=node16-linux --options max_old_space_size=4096 -o /build/docservice


## Final image
FROM onlyoffice/documentserver:${product_version}
ARG oo_root

RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
#server
COPY --from=build-stage /build/converter  ${oo_root}/server/FileConverter/converter
COPY --from=build-stage /build/docservice ${oo_root}/server/DocService/docservice