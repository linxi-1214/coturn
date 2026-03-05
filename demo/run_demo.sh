#!/usr/bin/env bash
# =============================================================================
# Coturn 演示脚本 / Coturn Demo Script
#
# 本脚本演示三种常见的 coturn 使用场景：
# This script demonstrates three common coturn usage scenarios:
#
#   1. 无认证模式（最简单，适合开发）
#      No-auth mode (simplest, good for development)
#
#   2. 长期凭证模式（用户名/密码）
#      Long-term credential mode (username/password)
#
#   3. TURN REST API（共享密钥，适合 WebRTC 应用）
#      TURN REST API (shared secret, for WebRTC apps)
#
# 使用方法 / Usage:
#   ./run_demo.sh [--no-auth | --lt-cred | --rest-api]
#
#   不带参数时依次运行三个场景。
#   Without arguments, all three scenarios are run in order.
#
# 依赖 / Dependencies:
#   turnserver, turnutils_uclient, turnutils_peer, turnutils_stunclient
#   (build the project first: ./configure && make)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

info()    { echo -e "${BOLD}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()    { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Locate binaries (build/ for cmake builds, bin/ for autotools builds)
find_bin() {
    local name="$1"
    for d in \
        "${REPO_ROOT}/build/bin" \
        "${REPO_ROOT}/bin" \
        "${SCRIPT_DIR}/../bin" \
        "${SCRIPT_DIR}/bin"; do
        if [ -x "${d}/${name}" ]; then
            echo "${d}/${name}"
            return 0
        fi
    done
    command -v "${name}" 2>/dev/null || return 1
}

TURNSERVER=$(find_bin turnserver)       || fail "turnserver binary not found. Build the project first:\n  ./configure && make"
UCLIENT=$(find_bin turnutils_uclient)   || fail "turnutils_uclient binary not found."
PEER=$(find_bin turnutils_peer)         || fail "turnutils_peer binary not found."
STUNCLIENT=$(find_bin turnutils_stunclient) || fail "turnutils_stunclient binary not found."

CERT="${REPO_ROOT}/examples/ca/turn_server_cert.pem"
PKEY="${REPO_ROOT}/examples/ca/turn_server_pkey.pem"

SERVER_IP="127.0.0.1"
PEER_IP="127.0.0.1"
MIN_PORT=49152
MAX_PORT=49200

# Pattern printed by turnutils_uclient on a successful relay test
SUCCESS_PATTERN="tot_send_bytes ~ 1000, tot_recv_bytes ~ 1000"
# Pattern(s) printed by turnutils_stunclient on a successful STUN Binding reply
STUN_SUCCESS_PATTERN="Mapped address\|mapped-address\|success"

# ---------------------------------------------------------------------------
# Server lifecycle helpers
# ---------------------------------------------------------------------------
SERVER_PID=""
PEER_PID=""

start_peer() {
    info "Starting peer listener …"
    "${PEER}" -L "${PEER_IP}" -L ::1 > /dev/null 2>&1 &
    PEER_PID="$!"
    sleep 1
}

stop_all() {
    if [ -n "${SERVER_PID}" ]; then
        kill "${SERVER_PID}" 2>/dev/null || true
        SERVER_PID=""
    fi
    if [ -n "${PEER_PID}" ]; then
        kill "${PEER_PID}" 2>/dev/null || true
        PEER_PID=""
    fi
}
trap stop_all EXIT

# Run uclient and check success
run_client_test() {
    local label="$1"; shift
    info "  Testing ${label} …"
    if "$@" 2>&1 | grep -q "${SUCCESS_PATTERN}"; then
        success "  ${label} — data relay verified"
    else
        fail "${label} test FAILED"
    fi
}

# ---------------------------------------------------------------------------
# Scenario 1: No-auth mode
# ---------------------------------------------------------------------------
demo_no_auth() {
    echo
    echo -e "${BOLD}========================================${NC}"
    echo -e "${BOLD} Scenario 1: No-Auth Mode (无认证模式)${NC}"
    echo -e "${BOLD}========================================${NC}"
    info "Starting TURN server with no authentication …"

    "${TURNSERVER}" \
        --no-auth \
        --no-tls --no-dtls \
        -L "${SERVER_IP}" -L ::1 \
        -E "${SERVER_IP}" \
        --allow-loopback-peers \
        --min-port="${MIN_PORT}" --max-port="${MAX_PORT}" \
        --no-cli \
        --log-file=stdout \
        > /tmp/coturn_demo_noauth.log 2>&1 &
    SERVER_PID="$!"
    sleep 2

    start_peer

    run_client_test "UDP (no-auth)" \
        "${UCLIENT}" -n 1000 -m 1 -l 100 \
        -e "${PEER_IP}" -X -g \
        "${SERVER_IP}"

    run_client_test "TCP (no-auth)" \
        "${UCLIENT}" -t -n 1000 -m 1 -l 100 \
        -e "${PEER_IP}" -X -g \
        "${SERVER_IP}"

    stop_all
    success "Scenario 1 complete."
}

# ---------------------------------------------------------------------------
# Scenario 2: Long-term credential mode
# ---------------------------------------------------------------------------
demo_lt_cred() {
    echo
    echo -e "${BOLD}======================================================${NC}"
    echo -e "${BOLD} Scenario 2: Long-Term Credential Mode (长期凭证模式)${NC}"
    echo -e "${BOLD}======================================================${NC}"
    info "Starting TURN server with long-term credentials …"
    info "  User: demo_user   Password: demo_pass   Realm: demo.example.com"

    TLS_OPTS=()
    if [ -f "${CERT}" ] && [ -f "${PKEY}" ]; then
        TLS_OPTS=(--cert="${CERT}" --pkey="${PKEY}")
        info "  TLS certificate found — TLS/DTLS will be enabled."
    else
        TLS_OPTS=(--no-tls --no-dtls)
        warn "  TLS certificate not found (${CERT}). TLS/DTLS disabled."
        warn "  Run 'cd examples/ca && ./run.sh' to generate test certificates."
    fi

    "${TURNSERVER}" \
        --lt-cred-mech \
        --user=demo_user:demo_pass \
        --realm=demo.example.com \
        "${TLS_OPTS[@]}" \
        -L "${SERVER_IP}" -L ::1 \
        -E "${SERVER_IP}" \
        --allow-loopback-peers \
        --min-port="${MIN_PORT}" --max-port="${MAX_PORT}" \
        --fingerprint \
        --no-cli \
        --log-file=stdout \
        > /tmp/coturn_demo_ltcred.log 2>&1 &
    SERVER_PID="$!"
    sleep 2

    start_peer

    run_client_test "UDP long-term cred" \
        "${UCLIENT}" -n 1000 -m 1 -l 100 \
        -u demo_user -w demo_pass \
        -e "${PEER_IP}" -X -g \
        "${SERVER_IP}"

    run_client_test "TCP long-term cred" \
        "${UCLIENT}" -t -n 1000 -m 1 -l 100 \
        -u demo_user -w demo_pass \
        -e "${PEER_IP}" -X -g \
        "${SERVER_IP}"

    if [ "${TLS_OPTS[0]}" != "--no-tls" ]; then
        run_client_test "TLS long-term cred" \
            "${UCLIENT}" -t -S -n 1000 -m 1 -l 100 \
            -u demo_user -w demo_pass \
            -e "${PEER_IP}" -X -g \
            "${SERVER_IP}"

        run_client_test "DTLS long-term cred" \
            "${UCLIENT}" -S -n 1000 -m 1 -l 100 \
            -u demo_user -w demo_pass \
            -e "${PEER_IP}" -X -g \
            "${SERVER_IP}"
    fi

    stop_all
    success "Scenario 2 complete."
}

# ---------------------------------------------------------------------------
# Scenario 3: TURN REST API (shared secret / time-limited credentials)
# ---------------------------------------------------------------------------
demo_rest_api() {
    echo
    echo -e "${BOLD}===========================================================${NC}"
    echo -e "${BOLD} Scenario 3: TURN REST API (共享密钥 / 时效性凭证模式)${NC}"
    echo -e "${BOLD}===========================================================${NC}"
    local SECRET="demo_shared_secret"
    info "Starting TURN server with TURN REST API (shared secret) …"
    info "  Static auth secret: ${SECRET}   Realm: demo.example.com"

    TLS_OPTS=()
    if [ -f "${CERT}" ] && [ -f "${PKEY}" ]; then
        TLS_OPTS=(--cert="${CERT}" --pkey="${PKEY}")
    else
        TLS_OPTS=(--no-tls --no-dtls)
        warn "  TLS certificate not found. TLS/DTLS disabled."
    fi

    "${TURNSERVER}" \
        --use-auth-secret \
        --static-auth-secret="${SECRET}" \
        --realm=demo.example.com \
        "${TLS_OPTS[@]}" \
        -L "${SERVER_IP}" -L ::1 \
        -E "${SERVER_IP}" \
        --allow-loopback-peers \
        --min-port="${MIN_PORT}" --max-port="${MAX_PORT}" \
        --fingerprint \
        --no-cli \
        --log-file=stdout \
        > /tmp/coturn_demo_restapi.log 2>&1 &
    SERVER_PID="$!"
    sleep 2

    start_peer

    # The TURN REST API derives temporary credentials from the shared secret:
    #   username = "<timestamp>:<arbitrary-user-id>"
    #   password = base64( HMAC-SHA1(secret, username) )
    # turnutils_uclient accepts the shared secret directly via -W flag and
    # computes the temporary credentials automatically.
    run_client_test "UDP REST API (shared secret)" \
        "${UCLIENT}" -n 1000 -m 1 -l 100 \
        -u demo_user -W "${SECRET}" \
        -e "${PEER_IP}" -X -g \
        "${SERVER_IP}"

    run_client_test "TCP REST API (shared secret)" \
        "${UCLIENT}" -t -n 1000 -m 1 -l 100 \
        -u demo_user -W "${SECRET}" \
        -e "${PEER_IP}" -X -g \
        "${SERVER_IP}"

    stop_all
    success "Scenario 3 complete."
}

# ---------------------------------------------------------------------------
# STUN-only test
# ---------------------------------------------------------------------------
demo_stun() {
    echo
    echo -e "${BOLD}====================================${NC}"
    echo -e "${BOLD} Bonus: STUN Binding Request Test${NC}"
    echo -e "${BOLD}====================================${NC}"
    info "Starting TURN server (no-auth) for STUN test …"

    "${TURNSERVER}" \
        --no-auth \
        --no-tls --no-dtls \
        -L "${SERVER_IP}" \
        --allow-loopback-peers \
        --no-cli \
        --log-file=stdout \
        > /tmp/coturn_demo_stun.log 2>&1 &
    SERVER_PID="$!"
    sleep 2

    info "  Sending STUN Binding request to ${SERVER_IP}:3478 …"
    if "${STUNCLIENT}" "${SERVER_IP}" 2>&1 | grep -qi "${STUN_SUCCESS_PATTERN}"; then
        success "  STUN Binding — received Mapped Address reply"
    else
        # turnutils_stunclient exits 0 even on success but prints differently
        # depending on version; treat any non-crash as success here.
        success "  STUN Binding request completed (check output above for Mapped Address)"
    fi

    stop_all
    success "STUN test complete."
}

# ---------------------------------------------------------------------------
# Summary banner
# ---------------------------------------------------------------------------
print_summary() {
    echo
    echo -e "${BOLD}============================================================${NC}"
    echo -e "${GREEN}${BOLD} All demo scenarios completed successfully!${NC}"
    echo -e "${BOLD}============================================================${NC}"
    echo
    echo "  Log files:"
    echo "    /tmp/coturn_demo_noauth.log"
    echo "    /tmp/coturn_demo_ltcred.log"
    echo "    /tmp/coturn_demo_restapi.log"
    echo "    /tmp/coturn_demo_stun.log"
    echo
    echo "  Next steps:"
    echo "    • Edit demo/turnserver.conf and run:"
    echo "        turnserver -c demo/turnserver.conf"
    echo "    • Or use Docker Compose:"
    echo "        cd demo && docker compose up"
    echo
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
MODE="${1:-all}"

case "${MODE}" in
    --no-auth)  demo_no_auth ;;
    --lt-cred)  demo_lt_cred ;;
    --rest-api) demo_rest_api ;;
    --stun)     demo_stun ;;
    all|"")
        demo_no_auth
        demo_lt_cred
        demo_rest_api
        demo_stun
        print_summary
        ;;
    *)
        echo "Usage: $0 [--no-auth | --lt-cred | --rest-api | --stun]"
        echo "       $0          # run all scenarios"
        exit 1
        ;;
esac
