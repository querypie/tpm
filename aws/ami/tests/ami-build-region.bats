#!/usr/bin/env bats

setup() {
  TEST_ROOT=$(mktemp -d)
  MOCK_BIN="$TEST_ROOT/bin"
  mkdir -p "$MOCK_BIN"

  cat >"$MOCK_BIN/aws" <<'EOF'
#!/usr/bin/env bash
set -o nounset -o errexit -o pipefail

arguments=" $* "

if [[ "$arguments" == *" sts get-caller-identity "* ]]; then
  printf 'AROAEXAMPLE\t123456789012\tarn:aws:sts::123456789012:assumed-role/test/session\n'
elif [[ "$arguments" == *" ec2 get-ebs-encryption-by-default "* ]]; then
  printf '%s\n' "${MOCK_EBS_ENCRYPTION_BY_DEFAULT:-False}"
elif [[ "$arguments" == *" ec2 describe-images "* && "$arguments" == *"sort_by(Images"* ]]; then
  printf 'ami-0123456789abcdef0\n'
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
