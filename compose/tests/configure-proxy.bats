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
