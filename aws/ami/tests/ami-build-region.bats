#!/usr/bin/env bats

setup() {
  TEST_ROOT=$(mktemp -d)
  MOCK_BIN="$TEST_ROOT/bin"
  mkdir -p "$MOCK_BIN"

  cat >"$MOCK_BIN/aws" <<'EOF'
#!/usr/bin/env bash
set -o nounset -o errexit -o pipefail

arguments=" $* "

if [[ "$arguments" == *" ec2 describe-images "* && "$arguments" == *"State,Architecture,RootDeviceType"* ]]; then
  printf '%b\n' 'available\tx86_64\tebs\thvm\tv2.0\tQueryPie Suite'
elif [[ "$arguments" == *" sts get-caller-identity "* ]]; then
  printf 'AROAEXAMPLE\t123456789012\tarn:aws:sts::123456789012:assumed-role/test/session\n'
elif [[ "$arguments" == *" ec2 get-ebs-encryption-by-default "* ]]; then
  printf '%s\n' "${MOCK_EBS_ENCRYPTION_BY_DEFAULT:-False}"
elif [[ "$arguments" == *" ec2 describe-images "* && "$arguments" == *"sort_by(Images"* ]]; then
  printf 'ami-0123456789abcdef0\n'
elif [[ "$arguments" == *" ec2 describe-images "* && "$arguments" == *"VolumeSize"* ]]; then
  printf '32\n'
elif [[ "$arguments" == *" ec2 describe-images "* && "$arguments" == *"SnapshotId"* ]]; then
  printf 'snap-0123456789abcdef0\n'
elif [[ "$arguments" == *" ec2 describe-snapshots "* ]]; then
  printf 'False\n'
else
  printf 'Unexpected aws invocation: %s\n' "$*" >&2
  exit 2
fi
EOF
  chmod +x "$MOCK_BIN/aws"

  cat >"$MOCK_BIN/packer" <<'EOF'
#!/usr/bin/env bash
set -o nounset -o errexit -o pipefail

printf '%s\n' "$*" >>"$PACKER_INVOCATIONS_FILE"
EOF
  chmod +x "$MOCK_BIN/packer"

  cat >"$MOCK_BIN/session-manager-plugin" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$MOCK_BIN/session-manager-plugin"

  PACKER_INVOCATIONS_FILE="$TEST_ROOT/packer-invocations"
  export PACKER_INVOCATIONS_FILE
  : >"$PACKER_INVOCATIONS_FILE"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "AMI build forwards a non-default build region" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    AMI_REGION=ap-southeast-1 \
    USER=test-builder \
    "$BATS_TEST_DIRNAME/../ami-build.sh" 11.6.0 amazon-linux-2023 x86_64

  [ "$status" -eq 0 ]
  [[ "$output" == *"Built AMI: ami-0123456789abcdef0"* ]]
  grep -F -- '-var region=ap-southeast-1' "$PACKER_INVOCATIONS_FILE"
}

@test "AMI build stops before Packer when default EBS encryption is enabled" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    AMI_REGION=ap-northeast-2 \
    MOCK_EBS_ENCRYPTION_BY_DEFAULT=True \
    "$BATS_TEST_DIRNAME/../ami-build.sh" 11.6.0 amazon-linux-2023 x86_64

  [ "$status" -eq 1 ]
  [[ "$output" == *"EBS encryption by default must be disabled"* ]]
  [ ! -s "$PACKER_INVOCATIONS_FILE" ]
}

@test "AMI build stops before Packer when Session Manager plugin is missing" {
  rm "$MOCK_BIN/session-manager-plugin"

  run env \
    PATH="$MOCK_BIN:/usr/bin:/bin" \
    AMI_REGION=ap-northeast-2 \
    "$BATS_TEST_DIRNAME/../ami-build.sh" 11.6.0 amazon-linux-2023 x86_64

  [ "$status" -eq 1 ]
  [[ "$output" == *"AWS Session Manager plugin is not installed"* ]]
  [ ! -s "$PACKER_INVOCATIONS_FILE" ]
}

@test "AMI verification stops before Packer when Session Manager plugin is missing" {
  rm "$MOCK_BIN/session-manager-plugin"

  run env \
    PATH="$MOCK_BIN:/usr/bin:/bin" \
    AMI_REGION=ap-northeast-2 \
    "$BATS_TEST_DIRNAME/../ami-verify.sh" ami-0123456789abcdef0

  [ "$status" -eq 1 ]
  [[ "$output" == *"AWS Session Manager plugin is not installed"* ]]
  [ ! -s "$PACKER_INVOCATIONS_FILE" ]
}

@test "AMI template sets a maximum price for Spot Fleet builds" {
  run grep -F \
    'spot_price          = "0.09"' \
    "$BATS_TEST_DIRNAME/../ami-build.pkr.hcl"

  [ "$status" -eq 0 ]
}

@test "arm64 Spot builds include same-memory Graviton capacity fallbacks" {
  run grep -F \
    'var.architecture == "arm64" ? ["t4g.xlarge", "m7g.xlarge", "m6g.xlarge"]' \
    "$BATS_TEST_DIRNAME/../ami-build.pkr.hcl"

  [ "$status" -eq 0 ]
}

@test "AMI template does not request ENA modification for Spot builds" {
  run grep -F \
    'ena_support' \
    "$BATS_TEST_DIRNAME/../ami-build.pkr.hcl"

  [ "$status" -eq 1 ]
}

@test "AMI template assigns a public IP to remotely provisioned builders" {
  run grep -F \
    'associate_public_ip_address = true' \
    "$BATS_TEST_DIRNAME/../ami-build.pkr.hcl"

  [ "$status" -eq 0 ]
}

@test "AMI template restricts builders to default public subnets" {
  run grep -F \
    '"default-for-az" = "true"' \
    "$BATS_TEST_DIRNAME/../ami-build.pkr.hcl"

  [ "$status" -eq 0 ]
}

@test "AMI template tunnels SSH through Session Manager" {
  run grep -E \
    'ssh_interface[[:space:]]*=[[:space:]]*"session_manager"' \
    "$BATS_TEST_DIRNAME/../ami-build.pkr.hcl"
  [ "$status" -eq 0 ]

  run grep -E \
    'iam_instance_profile[[:space:]]*=[[:space:]]*"ec2-session-manager"' \
    "$BATS_TEST_DIRNAME/../ami-build.pkr.hcl"
  [ "$status" -eq 0 ]

  run grep -F \
    'temporary_security_group_source_public_ip' \
    "$BATS_TEST_DIRNAME/../ami-build.pkr.hcl"
  [ "$status" -eq 1 ]
}

@test "AMI verification tunnels SSH through Session Manager" {
  run grep -E \
    'ssh_interface[[:space:]]*=[[:space:]]*"session_manager"' \
    "$BATS_TEST_DIRNAME/../ami-verify.pkr.hcl"
  [ "$status" -eq 0 ]

  run grep -E \
    'iam_instance_profile[[:space:]]*=[[:space:]]*"ec2-session-manager"' \
    "$BATS_TEST_DIRNAME/../ami-verify.pkr.hcl"
  [ "$status" -eq 0 ]

  run grep -F \
    'temporary_security_group_source_public_ip' \
    "$BATS_TEST_DIRNAME/../ami-verify.pkr.hcl"
  [ "$status" -eq 1 ]
}

@test "Docker installation disconnects legacy and current AL2023 SSH sessions" {
  local installer="$BATS_TEST_DIRNAME/../../scripts/install-docker-on-amazon-linux-2023.sh"

  run grep -F \
    'killall sshd sshd-session' \
    "$installer"

  [ "$status" -eq 0 ]
}

@test "Docker Compose is installed as a system-wide CLI plugin for first boot" {
  local installer="$BATS_TEST_DIRNAME/../../scripts/install-docker-on-amazon-linux-2023.sh"

  run grep -F \
    'sudo install -m 755 -D /tmp/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose' \
    "$installer"

  [ "$status" -eq 0 ]
}

@test "AMI reserves QueryPie listener ports before first boot networking" {
  local sysctl_config="$BATS_TEST_DIRNAME/../99-querypie-ports.conf"

  run grep -F \
    'net.ipv4.ip_local_reserved_ports = 40000-40030' \
    "$sysctl_config"
  [ "$status" -eq 0 ]

  run grep -F \
    'sudo install -m 644 /tmp/99-querypie-ports.conf /etc/sysctl.d/99-querypie-ports.conf' \
    "$BATS_TEST_DIRNAME/../ami-build.pkr.hcl"
  [ "$status" -eq 0 ]

  run grep -F \
    'sudo sysctl --system' \
    "$BATS_TEST_DIRNAME/../ami-build.pkr.hcl"
  [ "$status" -eq 0 ]
}

@test "AMI sanitization resets machine identity without unsupported cloud-init flags" {
  local sanitizer="$BATS_TEST_DIRNAME/../sanitize-image-before-snapshot.sh"

  run grep -F \
    'sudo cloud-init clean --logs' \
    "$sanitizer"
  [ "$status" -eq 0 ]

  run grep -F \
    "printf 'uninitialized\\n' | sudo tee /etc/machine-id >/dev/null" \
    "$sanitizer"
  [ "$status" -eq 0 ]

  run grep -F \
    'sudo rm -f /var/lib/dbus/machine-id' \
    "$sanitizer"
  [ "$status" -eq 0 ]

  run grep -F \
    'cloud-init clean --logs --machine-id' \
    "$sanitizer"
  [ "$status" -eq 1 ]
}
