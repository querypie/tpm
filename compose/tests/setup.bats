#!/usr/bin/env bats
# Tests for compose/setup.v2.sh — install::base_url IP detection
#
# Run:
#   bats compose/tests/setup.bats

setup() {
    # Create a minimal compose.yml fixture in a temp working directory.
    WORK_DIR=$(mktemp -d)
    export QP_VERSION="0.0.0-test"
    mkdir -p "${WORK_DIR}/querypie/${QP_VERSION}"
    printf 'services:\n  app:\n    ports:\n      - "8080:80"\n      - "8443:443"\n' \
        > "${WORK_DIR}/querypie/${QP_VERSION}/docker-compose.yml"
    pushd "${WORK_DIR}" >/dev/null
}

teardown() {
    popd >/dev/null 2>&1 || true
    rm -rf "${WORK_DIR:-}"
}

# ---------------------------------------------------------------------------
# install::base_url IP detection: macOS must use darwin path even when ip exists
# ---------------------------------------------------------------------------

@test "install::base_url: on macOS uses route+ipconfig, not ip command" {
    run bash -c '
        source '"${BATS_TEST_DIRNAME}"'/../setup.v2.sh
        export QP_VERSION="0.0.0-test"
        mkdir -p querypie/0.0.0-test
        printf "services:\n  app:\n    ports:\n      - \"8080:80\"\n" \
            > querypie/0.0.0-test/docker-compose.yml
        OSTYPE=darwin20
        ip()       { echo "SHOULD_NOT_BE_CALLED"; }
        route()    { echo "   interface: en0"; }
        ipconfig() { echo "192.168.1.42"; }
        export -f ip route ipconfig
        install::base_url http
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"192.168.1.42"* ]]
    [[ "$output" != *"SHOULD_NOT_BE_CALLED"* ]]
}

@test "install::base_url: on Linux uses ip route with grep -oP" {
    echo '' | grep -P '' >/dev/null 2>&1 || skip "requires GNU grep (-P not supported)"
    run bash -c '
        source '"${BATS_TEST_DIRNAME}"'/../setup.v2.sh
        export QP_VERSION="0.0.0-test"
        mkdir -p querypie/0.0.0-test
        printf "services:\n  app:\n    ports:\n      - \"8080:80\"\n" \
            > querypie/0.0.0-test/docker-compose.yml
        OSTYPE=linux-gnu
        ip() {
            if [[ "$1 $2 $3" == "route get 8.8.8.8" ]]; then
                echo "8.8.8.8 via 192.168.1.1 dev eth0 src 172.16.0.10 uid 1000"
            fi
        }
        export -f ip
        install::base_url http
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"172.16.0.10"* ]]
}

@test "install::base_url: on Linux falls back to hostname -i when ip route fails" {
    echo '' | grep -P '' >/dev/null 2>&1 || skip "requires GNU grep (-P not supported)"
    run bash -c '
        source '"${BATS_TEST_DIRNAME}"'/../setup.v2.sh
        export QP_VERSION="0.0.0-test"
        mkdir -p querypie/0.0.0-test
        printf "services:\n  app:\n    ports:\n      - \"8080:80\"\n" \
            > querypie/0.0.0-test/docker-compose.yml
        OSTYPE=linux-gnu
        ip() { return 1; }
        hostname() { echo "10.20.30.40"; }
        export -f ip hostname
        install::base_url http
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"10.20.30.40"* ]]
}

@test "install::base_url: on Linux without ip falls back to hostname -i" {
    run bash -c '
        source '"${BATS_TEST_DIRNAME}"'/../setup.v2.sh
        export QP_VERSION="0.0.0-test"
        mkdir -p querypie/0.0.0-test
        printf "services:\n  app:\n    ports:\n      - \"8080:80\"\n" \
            > querypie/0.0.0-test/docker-compose.yml
        OSTYPE=linux-gnu
        hostname() { echo "10.10.10.99"; }
        export -f hostname
        PATH=/nonexistent install::base_url http
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"10.10.10.99"* ]]
}
