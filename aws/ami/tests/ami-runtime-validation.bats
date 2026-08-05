#!/usr/bin/env bats

setup() {
  TEST_ROOT=$(mktemp -d)
  MOCK_BIN="$TEST_ROOT/bin"
  mkdir -p "$MOCK_BIN"

  cat >"$MOCK_BIN/lsblk" <<'EOF'
#!/usr/bin/env bash
printf '%b' "${MOCK_LSBLK_OUTPUT:-disk\npart xfs\n}"
EOF
  chmod +x "$MOCK_BIN/lsblk"

  cat >"$MOCK_BIN/findmnt" <<'EOF'
#!/usr/bin/env bash
printf '%b' "${MOCK_FINDMNT_OUTPUT:-xfs\n}"
EOF
  chmod +x "$MOCK_BIN/findmnt"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "runtime validation rejects a LUKS-backed image" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_LSBLK_OUTPUT='disk\npart crypto_LUKS\ncrypt xfs\n' \
    "$BATS_TEST_DIRNAME/../validate-image-runtime.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"encrypted block device or filesystem"* ]]
}

@test "runtime validation accepts an image without encrypted filesystems" {
  run env \
    PATH="$MOCK_BIN:$PATH" \
    "$BATS_TEST_DIRNAME/../validate-image-runtime.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Image runtime checks completed"* ]]
}
