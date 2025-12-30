#!/bin/bash
# Build VoIP Docker images for ARM64
# Usage: ./build-images.sh [opensips|asterisk|all] [--push]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
REGISTRY="${REGISTRY:-localhost:3000/gator}"
OPENSIPS_VERSION="${OPENSIPS_VERSION:-3.5}"
ASTERISK_VERSION="${ASTERISK_VERSION:-20}"
PLATFORM="${PLATFORM:-linux/arm64}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

build_opensips() {
    log_info "Building OpenSIPS ${OPENSIPS_VERSION} image..."

    docker build \
        --platform "${PLATFORM}" \
        --build-arg OPENSIPS_VERSION="${OPENSIPS_VERSION}" \
        -t "${REGISTRY}/opensips:${OPENSIPS_VERSION}-arm64" \
        -t "${REGISTRY}/opensips:latest" \
        -f "${DOCKER_DIR}/opensips/Dockerfile" \
        "${DOCKER_DIR}/opensips"

    log_info "OpenSIPS image built successfully"
}

build_asterisk() {
    log_info "Building Asterisk ${ASTERISK_VERSION} image..."

    docker build \
        --platform "${PLATFORM}" \
        --build-arg ASTERISK_VERSION="${ASTERISK_VERSION}" \
        -t "${REGISTRY}/asterisk:${ASTERISK_VERSION}-arm64" \
        -t "${REGISTRY}/asterisk:latest" \
        -f "${DOCKER_DIR}/asterisk/Dockerfile" \
        "${DOCKER_DIR}/asterisk"

    log_info "Asterisk image built successfully"
}

push_images() {
    local component="$1"

    if [[ "$component" == "opensips" || "$component" == "all" ]]; then
        log_info "Pushing OpenSIPS images to registry..."
        docker push "${REGISTRY}/opensips:${OPENSIPS_VERSION}-arm64"
        docker push "${REGISTRY}/opensips:latest"
    fi

    if [[ "$component" == "asterisk" || "$component" == "all" ]]; then
        log_info "Pushing Asterisk images to registry..."
        docker push "${REGISTRY}/asterisk:${ASTERISK_VERSION}-arm64"
        docker push "${REGISTRY}/asterisk:latest"
    fi
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [component] [options]

Components:
    opensips    Build OpenSIPS image only
    asterisk    Build Asterisk image only
    all         Build all images (default)

Options:
    --push      Push images to registry after building

Environment Variables:
    REGISTRY            Registry URL (default: localhost:3000/gator)
    OPENSIPS_VERSION    OpenSIPS version (default: 3.5)
    ASTERISK_VERSION    Asterisk version (default: 20)
    PLATFORM            Target platform (default: linux/arm64)

Examples:
    $(basename "$0")                    # Build all images
    $(basename "$0") opensips           # Build OpenSIPS only
    $(basename "$0") all --push         # Build and push all images
    REGISTRY=forgejo.local:3000/gator $(basename "$0") --push

EOF
}

main() {
    local component="all"
    local push=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            opensips|asterisk|all)
                component="$1"
                shift
                ;;
            --push)
                push=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    log_info "Docker build configuration:"
    log_info "  Registry: ${REGISTRY}"
    log_info "  Platform: ${PLATFORM}"
    log_info "  Component: ${component}"

    case "$component" in
        opensips)
            build_opensips
            ;;
        asterisk)
            build_asterisk
            ;;
        all)
            build_opensips
            build_asterisk
            ;;
    esac

    if [[ "$push" == true ]]; then
        push_images "$component"
    fi

    log_info "Build complete!"

    # Show image sizes
    echo ""
    log_info "Image sizes:"
    docker images | grep -E "(opensips|asterisk)" | head -10 || true
}

main "$@"
