#!/usr/bin/env bash

set -o nounset -o errexit -o errtrace -o pipefail

if lsblk --noheadings --raw --output TYPE,FSTYPE |
  awk '$1 == "crypt" || $2 == "crypto_LUKS" { found = 1 } END { exit !found }'; then
  echo >&2 "ERROR: The image contains an encrypted block device or filesystem."
  exit 1
fi

if findmnt --noheadings --raw --output FSTYPE |
  awk '$1 ~ /^(ecryptfs|encfs|fuse\.encfs|fuse\.gocryptfs)$/ { found = 1 } END { exit !found }'; then
  echo >&2 "ERROR: The image contains an encrypted block device or filesystem."
  exit 1
fi

echo "### Image runtime checks completed"
