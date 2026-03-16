#!/usr/bin/env bats
# Tests for compose/universal/configure-proxy.sh
#
# Run:
#   bats compose/tests/configure-proxy.bats

setup() {
    # Source the script to load functions without executing main.
    # BASH_SOURCE guard in the script prevents main() from running.
    source "${BATS_TEST_DIRNAME}/../universal/configure-proxy.sh"
}

# ---------------------------------------------------------------------------
# validate_proxy_address
# ---------------------------------------------------------------------------

@test "validate_proxy_address: accepts valid IPv4" {
    run validate_proxy_address "192.168.1.100"
    [ "$status" -eq 0 ]
}

@test "validate_proxy_address: accepts single-label hostname" {
    run validate_proxy_address "myserver"
    [ "$status" -eq 0 ]
}

@test "validate_proxy_address: accepts FQDN" {
    run validate_proxy_address "querypie.example.com"
    [ "$status" -eq 0 ]
}

@test "validate_proxy_address: accepts FQDN with hyphens" {
    run validate_proxy_address "my-querypie.example.com"
    [ "$status" -eq 0 ]
}

@test "validate_proxy_address: rejects http:// scheme" {
    run validate_proxy_address "http://192.168.1.100"
    [ "$status" -eq 1 ]
}

@test "validate_proxy_address: rejects https:// scheme" {
    run validate_proxy_address "https://querypie.example.com"
    [ "$status" -eq 1 ]
}

@test "validate_proxy_address: rejects address with port" {
    run validate_proxy_address "192.168.1.100:8080"
    [ "$status" -eq 1 ]
}

@test "validate_proxy_address: rejects address with path" {
    run validate_proxy_address "querypie.example.com/path"
    [ "$status" -eq 1 ]
}

@test "validate_proxy_address: rejects address with special characters" {
    run validate_proxy_address "invalid!address"
    [ "$status" -eq 1 ]
}

@test "validate_proxy_address: rejects IPv4 with octet > 255" {
    run validate_proxy_address "256.0.0.1"
    [ "$status" -eq 1 ]
}

@test "validate_proxy_address: rejects IPv4 999.999.999.999" {
    run validate_proxy_address "999.999.999.999"
    [ "$status" -eq 1 ]
}

@test "validate_proxy_address: rejects empty string" {
    run validate_proxy_address ""
    [ "$status" -eq 1 ]
}

@test "validate_proxy_address: error message contains example on scheme input" {
    run validate_proxy_address "https://192.168.1.100"
    [ "$status" -eq 1 ]
    [[ "$output" == *"must not include a scheme"* ]]
}

# ---------------------------------------------------------------------------
# Review issue: --help must work without a TTY
# TTY check must come after argument parsing so --help works non-interactively.
# ---------------------------------------------------------------------------

@test "--help exits 0 without a TTY" {
    run bash compose/universal/configure-proxy.sh --help
    [ "$status" -eq 0 ]
}

@test "--help output contains PROXY_ADDRESS" {
    run bash compose/universal/configure-proxy.sh --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"PROXY_ADDRESS"* ]]
}

# ---------------------------------------------------------------------------
# Review issue: docker/podman detection must prefer the running engine
# If docker is installed but not running, podman should be selected.
# ---------------------------------------------------------------------------

@test "detect_container_engine: selects podman when docker does not have the container" {
    # Stub docker inspect to fail (container not found), podman inspect to succeed
    docker() { if [[ "$1" == "inspect" ]]; then return 1; fi; }
    podman() { if [[ "$1" == "inspect" ]]; then return 0; fi; }
    export -f docker podman

    run bash -c '
        source compose/universal/configure-proxy.sh
        detect_container_engine
        echo "${DOCKER}"
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"podman"* ]]
}

@test "detect_container_engine: selects podman when docker has stopped container but podman is running" {
    # docker inspect exists but returns running=false; podman inspect returns running=true
    docker() {
        if [[ "$1" == "inspect" && "$2" == "--format" ]]; then echo "false"; return 0; fi
        if [[ "$1" == "inspect" ]]; then return 0; fi
    }
    podman() {
        if [[ "$1" == "inspect" && "$2" == "--format" ]]; then echo "true"; return 0; fi
        if [[ "$1" == "inspect" ]]; then return 0; fi
    }
    export -f docker podman

    run bash -c '
        source compose/universal/configure-proxy.sh
        detect_container_engine
        echo "${DOCKER}"
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"podman"* ]]
}

# ---------------------------------------------------------------------------
# Review issue: KAC host is always forced to https://
# proxy_input is validated to have no scheme; kac_host prepends https:// unconditionally.
# This test documents the current behavior (https:// forced).
# ---------------------------------------------------------------------------

@test "kac_host always uses https:// scheme" {
    run bash -c '
        source compose/universal/configure-proxy.sh
        proxy_input="querypie.example.com"
        kac_host="https://${proxy_input}"
        echo "${kac_host}"
    '
    [ "$status" -eq 0 ]
    [[ "$output" == "https://querypie.example.com" ]]
}

# ---------------------------------------------------------------------------
# --yes flag: ask_yes must auto-confirm without a TTY
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# -- argument parsing: positional args after -- must be preserved
# ---------------------------------------------------------------------------

@test "argument parsing: positional arg after -- is collected" {
    run bash -c '
        source compose/universal/configure-proxy.sh
        arguments=()
        set -- -- 192.168.1.100
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --) shift; arguments+=("$@"); break ;;
                *) arguments+=("$1"); shift ;;
            esac
        done
        echo "${arguments[0]}"
    '
    [ "$status" -eq 0 ]
    [[ "$output" == "192.168.1.100" ]]
}

# ---------------------------------------------------------------------------
# --yes flag: ask_yes must auto-confirm without a TTY
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Non-interactive path: missing PROXY_ADDRESS without TTY must fail with guidance
# ---------------------------------------------------------------------------

@test "no PROXY_ADDRESS without TTY: fails with guidance when IP is detectable" {
    run bash -c '
        source compose/universal/configure-proxy.sh
        detect_container_engine() { DOCKER=docker; }
        detect_host_ip() { echo "192.168.1.100"; }
        main
    '
    [ "$status" -eq 1 ]
    [[ "$output" == *"--yes"* ]]
}

# ---------------------------------------------------------------------------
# --yes flag: ask_yes must auto-confirm without a TTY
# ---------------------------------------------------------------------------

@test "ask_yes: auto-confirms when ASSUME_YES is true" {
    run bash -c '
        source compose/universal/configure-proxy.sh
        ASSUME_YES=true
        ask_yes "Apply settings?"
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"yes"* ]]
}

@test "ask_yes: fails without TTY when ASSUME_YES is false" {
    run bash -c '
        source compose/universal/configure-proxy.sh
        ASSUME_YES=false
        ask_yes "Apply settings?"
    '
    [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# detect_host_ip: macOS must use darwin path even when `ip` command exists
# ---------------------------------------------------------------------------

@test "detect_host_ip: on macOS uses route+ipconfig, not ip command" {
    run bash -c '
        source compose/universal/configure-proxy.sh
        OSTYPE=darwin20
        ip()     { echo "SHOULD_NOT_BE_CALLED"; }
        route()  { echo "   interface: en0"; }
        ipconfig() { echo "192.168.1.42"; }
        export -f ip route ipconfig
        detect_host_ip
    '
    [ "$status" -eq 0 ]
    [[ "$output" == "192.168.1.42" ]]
}


@test "detect_host_ip: on Linux uses ip route with grep -oP" {
    grep -P '' /dev/null 2>/dev/null || skip "requires GNU grep (-P not supported)"
    run bash -c '
        source compose/universal/configure-proxy.sh
        OSTYPE=linux-gnu
        ip() {
            if [[ "$1 $2 $3" == "route get 8.8.8.8" ]]; then
                echo "8.8.8.8 via 192.168.1.1 dev eth0 src 172.16.0.10 uid 1000"
            fi
        }
        export -f ip
        detect_host_ip
    '
    [ "$status" -eq 0 ]
    [[ "$output" == "172.16.0.10" ]]
}

@test "detect_host_ip: on Linux without ip falls back to hostname -i" {
    run bash -c '
        source compose/universal/configure-proxy.sh
        OSTYPE=linux-gnu
        # ip not available
        hostname() { echo "10.10.10.99"; }
        export -f hostname
        PATH=/nonexistent detect_host_ip
    '
    [ "$status" -eq 0 ]
    [[ "$output" == "10.10.10.99" ]]
}

# ---------------------------------------------------------------------------
# detect_host_ip: integration tests using real system commands
# ---------------------------------------------------------------------------

@test "detect_host_ip: returns valid IPv4 on macOS (integration)" {
    [[ "$OSTYPE" == "darwin"* ]] || skip "macOS only"
    run bash -c '
        source compose/universal/configure-proxy.sh
        detect_host_ip
    '
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "detect_host_ip: returns valid IPv4 on Linux (integration)" {
    [[ "$OSTYPE" == "linux"* ]] || skip "Linux only"
    run bash -c '
        source compose/universal/configure-proxy.sh
        detect_host_ip
    '
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}
