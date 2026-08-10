#!/usr/bin/env bats

setup() {
  TEST_ROOT=$(mktemp -d)
  MOCK_BIN="$TEST_ROOT/bin"
  AWS_INVOCATIONS_FILE="$TEST_ROOT/aws-invocations"
  export AWS_INVOCATIONS_FILE
  mkdir -p "$MOCK_BIN"
  : >"$AWS_INVOCATIONS_FILE"

  cat >"$MOCK_BIN/aws" <<'EOF'
#!/usr/bin/env bash
set -o nounset -o errexit -o pipefail

printf 'profile=%s %s\n' "${AWS_PROFILE:-}" "$*" >>"$AWS_INVOCATIONS_FILE"

arguments=" $* "
profile="${AWS_PROFILE:-}"
previous=""
snapshot_id=""
for argument in "$@"; do
  if [[ "$previous" == "--profile" ]]; then
    profile=$argument
  elif [[ "$previous" == "--snapshot-id" ]]; then
    snapshot_id=$argument
  fi
  previous=$argument
done

if [[ "$arguments" == *" sts get-caller-identity "* ]]; then
  if [[ "$profile" == "qpe" ]]; then
    printf '%s\n' "${MOCK_QPE_ACCOUNT_ID:-142605707876}"
  elif [[ "$profile" == "sales" ]]; then
    printf '%s\n' "${MOCK_SALES_ACCOUNT_ID:-883790944456}"
  else
    printf 'Unexpected profile for STS: %s\n' "$profile" >&2
    exit 2
  fi
elif [[ "$arguments" == *" ec2 get-ebs-encryption-by-default "* ]]; then
  printf '%s\n' "${MOCK_SALES_EBS_ENCRYPTION_BY_DEFAULT:-False}"
elif [[ "$arguments" == *" ec2 describe-images "* && "$arguments" == *"State,Architecture,RootDeviceType"* ]]; then
  printf '%b\n' 'available\tx86_64\tebs\thvm\tv2.0\tQueryPie Suite'
elif [[ "$arguments" == *" ec2 describe-images "* && "$arguments" == *"VolumeSize"* ]]; then
  printf '32\n'
elif [[ "$arguments" == *" ec2 describe-images "* && "$arguments" == *"BlockDeviceMappings"* ]]; then
  printf '%s\n' "${MOCK_SNAPSHOT_IDS:-snap-0123456789abcdef0 snap-0fedcba9876543210}"
elif [[ "$arguments" == *" ec2 describe-snapshots "* ]]; then
  if [[ "$profile" == "sales" ]]; then
    printf '%s\n' "${MOCK_SALES_SNAPSHOT_ENCRYPTED:-False}"
  else
    printf 'False\n'
  fi
elif [[ "$arguments" == *" ec2 describe-images "* && "$arguments" == *"Images[0].[Name,Architecture]"* ]]; then
  printf '%b\n' 'QueryPie-Suite-11.6.5-202608071519\tx86_64'
elif [[ "$arguments" == *" ec2 describe-images "* && "$arguments" == *"Key=='Version'"* ]]; then
  printf '11.6.5\n'
elif [[ "$arguments" == *" ec2 describe-images "* && "$arguments" == *"Key=='BuildDate'"* ]]; then
  printf '20260807062224\n'
elif [[ "$arguments" == *" ec2 describe-image-attribute "* ]]; then
  if [[ "${MOCK_IMAGE_PERMISSION_DESCRIBE_FAILURE_AFTER_REVOKE:-false}" == "true" && -f "${AWS_INVOCATIONS_FILE}.image-permission-revoked" ]]; then
    printf 'image permission verification failed\n' >&2
    exit 2
  elif [[ -f "${AWS_INVOCATIONS_FILE}.image-permission-revoked" ]]; then
    printf 'None\n'
  elif [[ "${MOCK_PERMISSIONS_GRANTED:-false}" == "true" || "${MOCK_IMAGE_PERMISSION_GRANTED:-false}" == "true" || -f "${AWS_INVOCATIONS_FILE}.image-permission-added" ]]; then
    printf '883790944456\n'
  else
    printf 'None\n'
  fi
elif [[ "$arguments" == *" ec2 describe-snapshot-attribute "* ]]; then
  if [[ -f "${AWS_INVOCATIONS_FILE}.${snapshot_id}.permission-revoked" ]]; then
    printf 'None\n'
  elif [[ "${MOCK_PERMISSIONS_GRANTED:-false}" == "true" || -f "${AWS_INVOCATIONS_FILE}.${snapshot_id}.permission-added" ]]; then
    printf '883790944456\n'
  else
    printf 'None\n'
  fi
elif [[ "$arguments" == *" ec2 modify-image-attribute "* && "$arguments" == *"Add="* ]]; then
  printf 'true\n' >"${AWS_INVOCATIONS_FILE}.image-permission-added"
elif [[ "$arguments" == *" ec2 modify-snapshot-attribute "* && "$arguments" == *"--operation-type add"* ]]; then
  if [[ "${MOCK_SNAPSHOT_GRANT_FAILURE:-false}" == "true" && "$snapshot_id" == "snap-0123456789abcdef0" ]]; then
    printf 'snapshot grant failed\n' >&2
    exit 2
  fi
  printf 'true\n' >"${AWS_INVOCATIONS_FILE}.${snapshot_id}.permission-added"
elif [[ "$arguments" == *" ec2 modify-image-attribute "* && "$arguments" == *"Remove="* ]]; then
  if [[ "${MOCK_IMAGE_REVOKE_FAILURE:-false}" == "true" ]]; then
    printf 'image revoke failed\n' >&2
    exit 2
  fi
  printf 'true\n' >"${AWS_INVOCATIONS_FILE}.image-permission-revoked"
elif [[ "$arguments" == *" ec2 modify-snapshot-attribute "* && "$arguments" == *"--operation-type remove"* ]]; then
  printf 'true\n' >"${AWS_INVOCATIONS_FILE}.${snapshot_id}.permission-revoked"
elif [[ "$arguments" == *" ec2 describe-images "* && "$arguments" == *"Name=tag:SourceAMI"* ]]; then
  printf '%b\n' "${MOCK_EXISTING_TARGET_AMIS:-None}"
elif [[ "$arguments" == *" ec2 copy-image "* ]]; then
  if [[ "${MOCK_COPY_FAILURE:-false}" == "true" ]]; then
    printf 'copy failed\n' >&2
    exit 2
  fi
  printf 'ami-0fedcba9876543210\n'
elif [[ "$arguments" == *" ec2 describe-images "* && "$arguments" == *"Images[0].State"* ]]; then
  printf '%s\n' "${MOCK_TARGET_STATE:-available}"
else
  printf 'Unexpected aws invocation: profile=%s %s\n' "$profile" "$*" >&2
  exit 2
fi
EOF
  chmod +x "$MOCK_BIN/aws"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "promotion uses only the AMI ID and fixed account profiles and Regions" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    "$BATS_TEST_DIRNAME/../ami-promote-to-sales.sh" ami-0123456789abcdef0

  [ "$status" -eq 0 ]
  [[ "$output" == *"Promoted AMI: ami-0fedcba9876543210"* ]]
  [[ "$output" == *"Sales sharing revoked from QPE AMI: ami-0123456789abcdef0"* ]]
  grep -F -- '--profile qpe' "$AWS_INVOCATIONS_FILE"
  grep -F -- '--profile sales' "$AWS_INVOCATIONS_FILE"
  grep -F -- '--region ap-northeast-2' "$AWS_INVOCATIONS_FILE"
  grep -F -- '--region us-east-1' "$AWS_INVOCATIONS_FILE"
  grep -F -- '--name QueryPie-Suite-11.6.5-202608071519-ami-0123456789abcdef0' "$AWS_INVOCATIONS_FILE"
  grep -F -- '--no-encrypted' "$AWS_INVOCATIONS_FILE"
  grep -F -- 'Key=SourceAMI,Value=ami-0123456789abcdef0' "$AWS_INVOCATIONS_FILE"
}

@test "promotion grants and then revokes AMI and every snapshot permission" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    "$BATS_TEST_DIRNAME/../ami-promote-to-sales.sh" ami-0123456789abcdef0

  [ "$status" -eq 0 ]
  grep -F -- 'modify-image-attribute' "$AWS_INVOCATIONS_FILE" | grep -F -- 'Add=[{UserId=883790944456}]'
  grep -F -- 'modify-image-attribute' "$AWS_INVOCATIONS_FILE" | grep -F -- 'Remove=[{UserId=883790944456}]'
  [ "$(grep -F -- 'modify-snapshot-attribute' "$AWS_INVOCATIONS_FILE" | grep -F -c -- '--operation-type add')" -eq 2 ]
  [ "$(grep -F -- 'modify-snapshot-attribute' "$AWS_INVOCATIONS_FILE" | grep -F -c -- '--operation-type remove')" -eq 2 ]
}

@test "promotion aborts before sharing when the QPE profile uses the wrong account" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_QPE_ACCOUNT_ID=111122223333 \
    "$BATS_TEST_DIRNAME/../ami-promote-to-sales.sh" ami-0123456789abcdef0

  [ "$status" -eq 1 ]
  [[ "$output" == *"profile 'qpe' must use account 142605707876"* ]]
  ! grep -F -- 'modify-image-attribute' "$AWS_INVOCATIONS_FILE"
  ! grep -F -- 'modify-snapshot-attribute' "$AWS_INVOCATIONS_FILE"
}

@test "promotion aborts before sharing when the Sales profile uses the wrong account" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_SALES_ACCOUNT_ID=111122223333 \
    "$BATS_TEST_DIRNAME/../ami-promote-to-sales.sh" ami-0123456789abcdef0

  [ "$status" -eq 1 ]
  [[ "$output" == *"profile 'sales' must use account 883790944456"* ]]
  ! grep -F -- 'modify-image-attribute' "$AWS_INVOCATIONS_FILE"
  ! grep -F -- 'modify-snapshot-attribute' "$AWS_INVOCATIONS_FILE"
}

@test "promotion aborts before sharing when Sales default EBS encryption is enabled" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_SALES_EBS_ENCRYPTION_BY_DEFAULT=True \
    "$BATS_TEST_DIRNAME/../ami-promote-to-sales.sh" ami-0123456789abcdef0

  [ "$status" -eq 1 ]
  [[ "$output" == *"EBS encryption by default must be disabled in Sales us-east-1"* ]]
  ! grep -F -- 'modify-image-attribute' "$AWS_INVOCATIONS_FILE"
  ! grep -F -- 'modify-snapshot-attribute' "$AWS_INVOCATIONS_FILE"
}

@test "promotion reuses an available Sales AMI and only revokes stale source sharing" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_EXISTING_TARGET_AMIS=$'ami-0fedcba9876543210\tavailable' \
    MOCK_PERMISSIONS_GRANTED=true \
    "$BATS_TEST_DIRNAME/../ami-promote-to-sales.sh" ami-0123456789abcdef0

  [ "$status" -eq 0 ]
  ! grep -F -- 'ec2 copy-image' "$AWS_INVOCATIONS_FILE"
  ! grep -F -- 'modify-image-attribute' "$AWS_INVOCATIONS_FILE" | grep -F -- 'Add='
  grep -F -- 'modify-image-attribute' "$AWS_INVOCATIONS_FILE" | grep -F -- 'Remove=[{UserId=883790944456}]'
}

@test "promotion preserves sharing when the copy-image request outcome is unknown" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_COPY_FAILURE=true \
    "$BATS_TEST_DIRNAME/../ami-promote-to-sales.sh" ami-0123456789abcdef0

  [ "$status" -ne 0 ]
  [[ "$output" == *"copy may still be in progress"* ]]
  [[ "$output" == *"Re-run this command"* ]]
  ! grep -F -- 'modify-image-attribute' "$AWS_INVOCATIONS_FILE" | grep -F -- 'Remove='
  [ "$(grep -F -- 'modify-snapshot-attribute' "$AWS_INVOCATIONS_FILE" | grep -F -c -- '--operation-type remove' || true)" -eq 0 ]
}

@test "promotion preserves restored access when an existing Sales copy is pending" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_EXISTING_TARGET_AMIS=$'ami-0fedcba9876543210\tpending' \
    MOCK_TARGET_STATE=pending \
    MOCK_SNAPSHOT_GRANT_FAILURE=true \
    "$BATS_TEST_DIRNAME/../ami-promote-to-sales.sh" ami-0123456789abcdef0

  [ "$status" -ne 0 ]
  [[ "$output" == *"copy may still be in progress"* ]]
  ! grep -F -- 'modify-image-attribute' "$AWS_INVOCATIONS_FILE" | grep -F -- 'Remove='
  [ "$(grep -F -- 'modify-snapshot-attribute' "$AWS_INVOCATIONS_FILE" | grep -F -c -- '--operation-type remove' || true)" -eq 0 ]
}

@test "promotion retries cleanup for pre-existing sharing when permission grant fails" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_IMAGE_PERMISSION_GRANTED=true \
    MOCK_SNAPSHOT_GRANT_FAILURE=true \
    "$BATS_TEST_DIRNAME/../ami-promote-to-sales.sh" ami-0123456789abcdef0

  [ "$status" -ne 0 ]
  [[ "$output" == *"Revoking temporary Sales access"* ]]
  grep -F -- 'modify-image-attribute' "$AWS_INVOCATIONS_FILE" | grep -F -- 'Remove=[{UserId=883790944456}]'
  ! grep -F -- 'ec2 copy-image' "$AWS_INVOCATIONS_FILE"
}

@test "promotion reports an incomplete permission cleanup for retry" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_IMAGE_PERMISSION_GRANTED=true \
    MOCK_SNAPSHOT_GRANT_FAILURE=true \
    MOCK_IMAGE_REVOKE_FAILURE=true \
    "$BATS_TEST_DIRNAME/../ami-promote-to-sales.sh" ami-0123456789abcdef0

  [ "$status" -ne 0 ]
  [[ "$output" == *"Sales launch permission remains on AMI"* ]]
  [[ "$output" == *"Some source sharing permissions could not be revoked"* ]]
  [[ "$output" == *"Re-run this command"* ]]
}

@test "promotion treats permission verification API errors as cleanup failures" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_IMAGE_PERMISSION_DESCRIBE_FAILURE_AFTER_REVOKE=true \
    "$BATS_TEST_DIRNAME/../ami-promote-to-sales.sh" ami-0123456789abcdef0

  [ "$status" -ne 0 ]
  [[ "$output" == *"Could not inspect launch permissions"* ]]
  [[ "$output" == *"Some source sharing permissions could not be revoked"* ]]
  [[ "$output" == *"Re-run this command"* ]]
}

@test "promotion revokes source sharing when the completed Sales copy fails final validation" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_SALES_SNAPSHOT_ENCRYPTED=True \
    "$BATS_TEST_DIRNAME/../ami-promote-to-sales.sh" ami-0123456789abcdef0

  [ "$status" -ne 0 ]
  [[ "$output" == *"source sharing permissions will be revoked"* ]]
  grep -F -- 'modify-image-attribute' "$AWS_INVOCATIONS_FILE" | grep -F -- 'Remove=[{UserId=883790944456}]'
  [ "$(grep -F -- 'modify-snapshot-attribute' "$AWS_INVOCATIONS_FILE" | grep -F -c -- '--operation-type remove')" -eq 2 ]
}

@test "promotion leaves source sharing in place while the Sales copy state is uncertain" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_TARGET_STATE=transient \
    "$BATS_TEST_DIRNAME/../ami-promote-to-sales.sh" ami-0123456789abcdef0

  [ "$status" -ne 0 ]
  [[ "$output" == *"copy may still be in progress"* ]]
  ! grep -F -- 'modify-image-attribute' "$AWS_INVOCATIONS_FILE" | grep -F -- 'Remove='
  [ "$(grep -F -- 'modify-snapshot-attribute' "$AWS_INVOCATIONS_FILE" | grep -F -c -- '--operation-type remove' || true)" -eq 0 ]
}

@test "promotion replaces a terminal Sales AMI and revokes sharing after success" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_EXISTING_TARGET_AMIS=$'ami-0fedcba9876543210\tfailed' \
    MOCK_PERMISSIONS_GRANTED=true \
    "$BATS_TEST_DIRNAME/../ami-promote-to-sales.sh" ami-0123456789abcdef0

  [ "$status" -eq 0 ]
  [[ "$output" == *"creating replacement attempt 1"* ]]
  grep -F -- '--name QueryPie-Suite-11.6.5-202608071519-ami-0123456789abcdef0-retry-1' "$AWS_INVOCATIONS_FILE"
  grep -F -- '--client-token querypie-ami-0123456789abcdef0-us-east-1-retry-1' "$AWS_INVOCATIONS_FILE"
  grep -F -- 'modify-image-attribute' "$AWS_INVOCATIONS_FILE" | grep -F -- 'Remove=[{UserId=883790944456}]'
  [ "$(grep -F -- 'modify-snapshot-attribute' "$AWS_INVOCATIONS_FILE" | grep -F -c -- '--operation-type remove')" -eq 2 ]
}

@test "promotion rejects account and Region override options" {
  run "$BATS_TEST_DIRNAME/../ami-promote-to-sales.sh" \
    --qpe-profile another-profile \
    ami-0123456789abcdef0

  [ "$status" -eq 1 ]
  [[ "$output" == *"Unexpected option: --qpe-profile"* ]]
}

@test "promotion accepts the AMI ID after the option delimiter" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    "$BATS_TEST_DIRNAME/../ami-promote-to-sales.sh" -- ami-0123456789abcdef0

  [ "$status" -eq 0 ]
  [[ "$output" == *"Promoted AMI: ami-0fedcba9876543210"* ]]
}

@test "promotion rejects invalid AMI IDs before calling AWS" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    "$BATS_TEST_DIRNAME/../ami-promote-to-sales.sh" not-an-ami

  [ "$status" -eq 1 ]
  [[ "$output" == *"AMI ID must use the format"* ]]
  [ ! -s "$AWS_INVOCATIONS_FILE" ]
}

@test "promotion rejects duplicate Sales AMIs before changing source permissions" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_EXISTING_TARGET_AMIS=$'ami-0fedcba9876543210\tavailable\nami-0abcdef0123456789\tpending' \
    "$BATS_TEST_DIRNAME/../ami-promote-to-sales.sh" ami-0123456789abcdef0

  [ "$status" -ne 0 ]
  [[ "$output" == *"Found 2 active Sales AMIs"* ]]
  ! grep -F -- 'modify-image-attribute' "$AWS_INVOCATIONS_FILE"
  ! grep -F -- 'modify-snapshot-attribute' "$AWS_INVOCATIONS_FILE"
}
