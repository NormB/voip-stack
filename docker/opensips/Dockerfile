# OpenSIPS Docker Image - Multi-stage Build
# Optimized for ARM64 (Apple Silicon)
#
# Build: docker build -t opensips:3.5-arm64 .
# Run: docker run --network host -v ./opensips.cfg:/etc/opensips/opensips.cfg opensips:3.5-arm64

# ============================================================================
# Stage 1: Builder
# ============================================================================
FROM debian:bookworm-slim AS builder

# Build arguments
ARG OPENSIPS_VERSION=3.5
ARG OPENSIPS_GIT_REPO=https://github.com/OpenSIPS/opensips.git

# Modules to include in the build
ARG INCLUDE_MODULES="\
    db_postgres \
    cachedb_redis \
    httpd \
    json \
    proto_tls \
    proto_wss \
    tls_mgm \
    tls_openssl \
    dispatcher \
    drouting \
    dialog \
    registrar \
    usrloc \
    auth \
    auth_db \
    load_balancer \
    topology_hiding \
    nat_traversal \
    rtpproxy \
    rtpengine \
    mediaproxy \
    acc \
    acc_json \
    proto_hep \
    sipcapture \
    cfgutils \
    exec \
    rest_client \
    regex"

# Modules to exclude from the build
ARG EXCLUDE_MODULES="\
    db_mysql \
    db_oracle \
    db_berkeley \
    db_sqlite \
    db_unixodbc \
    db_perlvdb \
    snmpstats \
    mi_xmlrpc \
    mi_xmlrpc_ng \
    event_xmlrpc \
    osp \
    aaa_diameter \
    aaa_radius \
    ldap \
    lua \
    perl \
    python \
    java \
    carrierroute \
    mmgeoip \
    h350 \
    presence \
    presence_callinfo \
    presence_dialoginfo \
    presence_mwi \
    presence_xml \
    pua \
    pua_bla \
    pua_dialoginfo \
    pua_mi \
    pua_reginfo \
    pua_usrloc \
    pua_xmpp \
    rls \
    xcap \
    xcap_client \
    auth_jwt \
    auth_aka \
    aka_av_diameter \
    compression \
    cachedb_cassandra \
    cachedb_couchbase \
    cachedb_memcached \
    cachedb_mongodb \
    event_kafka \
    event_rabbitmq \
    rabbitmq \
    rabbitmq_consumer \
    http2d \
    launch_darkly \
    identity \
    stir_shaken \
    sngtc \
    jabber \
    xmpp \
    cgrates \
    freeswitch \
    freeswitch_scripting \
    proto_ipsec \
    proto_sctp \
    proto_smpp \
    tls_wolfssl"

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # CA certificates (needed for git clone over HTTPS)
    ca-certificates \
    # Core build tools
    build-essential \
    gcc \
    make \
    bison \
    flex \
    git \
    pkg-config \
    # SSL/TLS
    openssl \
    libssl-dev \
    # XML and parsing
    libxml2-dev \
    libpcre3-dev \
    libexpat1-dev \
    # HTTP and network
    libcurl4-openssl-dev \
    libmicrohttpd-dev \
    # JSON
    libjson-c-dev \
    # Database clients
    libpq-dev \
    libhiredis-dev \
    # Compression
    zlib1g-dev \
    # UUID
    uuid-dev \
    # ncurses
    libncurses5-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone OpenSIPS source
RUN git clone --depth 1 -b ${OPENSIPS_VERSION} ${OPENSIPS_GIT_REPO} /src/opensips

WORKDIR /src/opensips

# Compile OpenSIPS
# Note: -fPIC is required for ARM64 shared library compilation
RUN make \
    prefix=/ \
    CFLAGS="-O2 -fPIC" \
    include_modules="${INCLUDE_MODULES}" \
    exclude_modules="${EXCLUDE_MODULES}" \
    -j$(nproc) \
    all

# Install to staging directory
# Note: OpenSIPS uses BASEDIR (not DESTDIR) for staging installs
RUN make \
    prefix=/ \
    BASEDIR=/opensips-install \
    include_modules="${INCLUDE_MODULES}" \
    exclude_modules="${EXCLUDE_MODULES}" \
    install

# ============================================================================
# Stage 2: Runtime
# ============================================================================
FROM debian:bookworm-slim

LABEL maintainer="voip-stack"
LABEL description="OpenSIPS SIP Proxy Server"
LABEL version="3.5"

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    # SSL/TLS runtime
    openssl \
    libssl3 \
    ca-certificates \
    # XML and parsing runtime
    libxml2 \
    libpcre3 \
    libexpat1 \
    # HTTP and network runtime
    libcurl4 \
    libmicrohttpd12 \
    # JSON runtime
    libjson-c5 \
    # Database client runtime
    libpq5 \
    libhiredis0.14 \
    # UUID runtime
    libuuid1 \
    # Useful debugging tools (minimal)
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -r -s /sbin/nologin opensips

# Copy compiled OpenSIPS from builder stage
COPY --from=builder /opensips-install/ /

# Create required directories
RUN mkdir -p \
    /etc/opensips/tls \
    /var/run/opensips \
    /var/log/opensips \
    && chown -R opensips:opensips \
    /etc/opensips \
    /var/run/opensips \
    /var/log/opensips

# Expose SIP ports
# Note: When using --network=host, these are informational only
EXPOSE 5060/udp
EXPOSE 5060/tcp
EXPOSE 5061/tcp
EXPOSE 8080/tcp
EXPOSE 8443/tcp

# Health check - verify OpenSIPS is responding
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD nc -z localhost 5060 || exit 1

# Volume for configuration
VOLUME ["/etc/opensips"]

# Run as opensips user
USER opensips

# Default entrypoint
ENTRYPOINT ["/sbin/opensips"]

# Default command - foreground mode
# Note: -E is deprecated in 3.4+, use stderror_enabled=yes in config instead
CMD ["-F"]
