# Asterisk Docker Image - Multi-stage Build
# Optimized for ARM64 (Apple Silicon)
#
# Build: docker build -t asterisk:20-arm64 .
# Run: docker run --network host -v ./asterisk:/etc/asterisk asterisk:20-arm64

# ============================================================================
# Stage 1: Builder
# ============================================================================
FROM debian:bookworm-slim AS builder

# Build arguments
ARG ASTERISK_VERSION=20
ARG ASTERISK_DOWNLOAD_URL=https://downloads.asterisk.org/pub/telephony/asterisk

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # CA certificates (needed for downloads)
    ca-certificates \
    # Core build tools
    build-essential \
    gcc \
    g++ \
    make \
    git \
    wget \
    curl \
    patch \
    pkg-config \
    autoconf \
    automake \
    libtool \
    # Development libraries
    libssl-dev \
    libncurses5-dev \
    libnewt-dev \
    libxml2-dev \
    libsqlite3-dev \
    uuid-dev \
    libjansson-dev \
    libedit-dev \
    # Audio/codec libraries
    libspeex-dev \
    libspeexdsp-dev \
    libopus-dev \
    libvorbis-dev \
    # SIP and RTP
    libsrtp2-dev \
    # PostgreSQL
    libpq-dev \
    # Lua (for dialplan)
    liblua5.2-dev \
    # ODBC
    unixodbc-dev \
    # Curl for ARI
    libcurl4-openssl-dev \
    # libxml2 for PJSIP
    libxslt1-dev \
    && rm -rf /var/lib/apt/lists/*

# Download and extract Asterisk
WORKDIR /src
RUN wget -q ${ASTERISK_DOWNLOAD_URL}/asterisk-${ASTERISK_VERSION}-current.tar.gz \
    && tar xzf asterisk-${ASTERISK_VERSION}-current.tar.gz \
    && rm asterisk-${ASTERISK_VERSION}-current.tar.gz \
    && mv asterisk-${ASTERISK_VERSION}* asterisk

WORKDIR /src/asterisk

# Install additional sound files and codecs
RUN contrib/scripts/get_mp3_source.sh || true

# Configure Asterisk
# Disable problematic modules, enable what we need
RUN ./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --localstatedir=/var \
    --with-pjproject-bundled \
    --with-jansson-bundled \
    --with-crypto \
    --with-ssl \
    --with-srtp \
    --with-postgres \
    --without-mysql \
    --without-native \
    CFLAGS="-O2 -fPIC"

# Generate menuselect options
RUN make menuselect.makeopts

# Enable/disable modules via menuselect
RUN menuselect/menuselect \
    --enable CORE-SOUNDS-EN-ULAW \
    --enable CORE-SOUNDS-EN-ALAW \
    --enable CORE-SOUNDS-EN-GSM \
    --enable MOH-OPSOUND-ULAW \
    --enable MOH-OPSOUND-ALAW \
    --enable res_pjsip \
    --enable res_pjsip_session \
    --enable res_pjsip_registrar \
    --enable res_pjsip_authenticator_digest \
    --enable res_pjsip_endpoint_identifier_ip \
    --enable res_pjsip_endpoint_identifier_user \
    --enable res_pjsip_outbound_authenticator_digest \
    --enable res_pjsip_caller_id \
    --enable res_pjsip_header_funcs \
    --enable res_pjsip_sdp_rtp \
    --enable res_pjsip_t38 \
    --enable res_pjsip_transport_websocket \
    --enable res_pjsip_pubsub \
    --enable res_pjsip_mwi \
    --enable res_pjsip_notify \
    --enable res_pjsip_dialog_info_body_generator \
    --enable res_pjsip_refer \
    --enable res_pjsip_dtmf_info \
    --enable res_stasis \
    --enable res_ari \
    --enable res_ari_channels \
    --enable res_ari_endpoints \
    --enable res_ari_applications \
    --enable res_http_websocket \
    --enable res_speech \
    --enable app_voicemail \
    --enable app_queue \
    --enable app_confbridge \
    --enable app_record \
    --enable app_playback \
    --enable app_dial \
    --enable app_transfer \
    --enable func_callerid \
    --enable func_channel \
    --enable func_pjsip_endpoint \
    --enable cdr_pgsql \
    --enable cel_pgsql \
    --disable chan_sip \
    menuselect.makeopts

# Build Asterisk
RUN make -j$(nproc) all

# Install to staging directory
RUN make DESTDIR=/asterisk-install install \
    && make DESTDIR=/asterisk-install samples \
    && make DESTDIR=/asterisk-install config

# ============================================================================
# Stage 2: Runtime
# ============================================================================
FROM debian:bookworm-slim

LABEL maintainer="voip-stack"
LABEL description="Asterisk PBX Server"
LABEL version="20"

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    # SSL/TLS runtime
    openssl \
    libssl3 \
    ca-certificates \
    # Runtime libraries
    libncurses6 \
    libnewt0.52 \
    libxml2 \
    libsqlite3-0 \
    libuuid1 \
    libjansson4 \
    libedit2 \
    # Audio/codec runtime
    libspeex1 \
    libspeexdsp1 \
    libopus0 \
    libvorbis0a \
    libvorbisenc2 \
    # SIP and RTP
    libsrtp2-1 \
    # PostgreSQL
    libpq5 \
    # Lua
    liblua5.2-0 \
    # ODBC
    unixodbc \
    # Curl
    libcurl4 \
    # xslt
    libxslt1.1 \
    # Useful tools
    netcat-openbsd \
    sox \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -r -s /sbin/nologin asterisk

# Copy compiled Asterisk from builder stage
COPY --from=builder /asterisk-install/ /

# Create required directories
RUN mkdir -p \
    /etc/asterisk \
    /var/lib/asterisk \
    /var/spool/asterisk \
    /var/spool/asterisk/voicemail \
    /var/spool/asterisk/recording \
    /var/spool/asterisk/monitor \
    /var/run/asterisk \
    /var/log/asterisk \
    && chown -R asterisk:asterisk \
    /etc/asterisk \
    /var/lib/asterisk \
    /var/spool/asterisk \
    /var/run/asterisk \
    /var/log/asterisk

# Expose ports
# Note: When using --network=host, these are informational only
# SIP over TCP/UDP (internal, from OpenSIPS only)
EXPOSE 5080/udp
EXPOSE 5080/tcp
# AMI
EXPOSE 5038/tcp
# ARI HTTP
EXPOSE 8088/tcp
EXPOSE 8089/tcp

# Health check - verify Asterisk is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD asterisk -rx "core show version" || exit 1

# Volumes for configuration and data
VOLUME ["/etc/asterisk", "/var/spool/asterisk", "/var/log/asterisk"]

# Run as asterisk user
USER asterisk

# Default entrypoint
ENTRYPOINT ["/usr/sbin/asterisk"]

# Default command - foreground mode with verbose and console output
CMD ["-fvvv", "-c"]
