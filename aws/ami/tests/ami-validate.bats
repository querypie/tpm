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
  printf '%b\n' "${MOCK_IMAGE_DETAILS:-available\\tx86_64\\tebs\\thvm\\tv2.0\\tQueryPie Suite}"
elif [[ "$arguments" == *" ec2 describe-images "* && "$arguments" == *"VolumeSize"* ]]; then
  printf '%s\n' "${MOCK_TOTAL_EBS_SIZE_GIB:-32}"
elif [[ "$arguments" == *" ec2 describe-images "* && "$arguments" == *"SnapshotId"* ]]; then
  printf 'snap-0123456789abcdef0\n'
elif [[ "$arguments" == *" ec2 describe-snapshots "* ]]; then
  printf '%s\n' "${MOCK_SNAPSHOT_ENCRYPTED:-False}"
else
  printf 'Unexpected aws invocation: %s\n' "$*" >&2
  exit 2
fi
EOF
  chmod +x "$MOCK_BIN/aws"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "Marketplace source validation rejects AMIs larger than 5 TiB" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    AMI_REGION=us-east-1 \
    MOCK_TOTAL_EBS_SIZE_GIB=5121 \
    "$BATS_TEST_DIRNAME/../ami-validate.sh" --marketplace-source ami-0123456789abcdef0

  [ "$status" -eq 1 ]
  [[ "$output" == *"Total EBS size"* ]]
}

@test "general validation accepts a structurally valid AMI outside us-east-1" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    AMI_REGION=ap-northeast-2 \
    "$BATS_TEST_DIRNAME/../ami-validate.sh" ami-0123456789abcdef0

  [ "$status" -eq 0 ]
  [[ "$output" == *"Region"*"ap-northeast-2"* ]]
}

@test "Marketplace source validation rejects a source outside us-east-1" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    AMI_REGION=ap-northeast-2 \
    "$BATS_TEST_DIRNAME/../ami-validate.sh" --marketplace-source ami-0123456789abcdef0

  [ "$status" -eq 1 ]
  [[ "$output" == *"Marketplace region must be 'us-east-1'"* ]]
}

@test "Marketplace source validation rejects an encrypted EBS snapshot" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    AMI_REGION=us-east-1 \
    MOCK_SNAPSHOT_ENCRYPTED=True \
    "$BATS_TEST_DIRNAME/../ami-validate.sh" --marketplace-source ami-0123456789abcdef0

  [ "$status" -eq 1 ]
  [[ "$output" == *"must be 'False', but found 'True'"* ]]
}

@test "validation rejects an AMI that is not owned by the active account" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    AMI_REGION=us-east-1 \
    MOCK_IMAGE_DETAILS=None \
    "$BATS_TEST_DIRNAME/../ami-validate.sh" --marketplace-source ami-0123456789abcdef0

  [ "$status" -eq 1 ]
  [[ "$output" == *"was not found in the current AWS account"* ]]
}
