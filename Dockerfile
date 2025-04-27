ARG product_version=7.1.0
ARG build_number=215
ARG oo_root='/var/www/onlyoffice/documentserver'

## Setup

FROM onlyoffice/documentserver:${product_version}.${build_number} as setup-stage
ARG product_version
ARG build_number
ARG oo_root
ENV PRODUCT_VERSION=${product_version}
ENV BUILD_NUMBER=${build_number}


ARG build_deps="git make g++ nodejs npm"
RUN apt-get update && apt-get install -y ${build_deps}
RUN npm install -g pkg grunt grunt-cli
WORKDIR /build


## Clone

FROM setup-stage as clone-stage
ARG tag=v${PRODUCT_VERSION}.${BUILD_NUMBER}
RUN git clone --quiet --branch $tag --depth 1 https://github.com/ONLYOFFICE/build_tools.git /build/build_tools
RUN git clone --quiet --branch $tag --depth 1 https://github.com/ONLYOFFICE/server.git      /build/server

COPY server/Makefile /build/server
COPY server/DocService/sources/server.js /build/server/DocService/sources
COPY server/FileConverter/sources/convertermaster.js /build/server/FileConverter/sources
COPY server/Common/sources/license.js /build/server/Common/sources
COPY server/Common/sources/constants.js /build/server/Common/sources

# COPY server.patch /build/server.patch
# RUN cd /build/server   && git apply /build/server.patch

## Build
FROM clone-stage as build-stage
WORKDIR /build/server
RUN make
RUN pkg /build/build_tools/out/linux_64/onlyoffice/documentserver/server/FileConverter --targets=node14-linux -o /build/converter
RUN pkg /build/build_tools/out/linux_64/onlyoffice/documentserver/server/DocService --targets=node14-linux --options max_old_space_size=4096 -o /build/docservice


## Final image
FROM onlyoffice/documentserver:${product_version}.${build_number}
ARG oo_root

#server
COPY --from=build-stage /build/converter  ${oo_root}/server/FileConverter/converter
COPY --from=build-stage /build/docservice ${oo_root}/server/DocService/docservice