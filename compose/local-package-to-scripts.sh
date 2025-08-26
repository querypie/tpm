#!/usr/bin/env bash
set -o nounset -o errexit -o xtrace

# Local Package Archive Script
# This script packages the contents of compose/universal into aws/scripts/package.tar.gz for local testing with setup.v2.sh.
#
# What it does:
# - Creates or overwrites aws/scripts/package.tar.gz built from compose/universal
# - Helps test setup.v2.sh and the configuration files in compose/universal/

SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
AWS_SCRIPTS_DIR=$(realpath "$SCRIPT_DIR/../aws/scripts")
pushd "$SCRIPT_DIR/universal"

[[ -f ${AWS_SCRIPTS_DIR}/package.tar.gz ]] && rm -f "${AWS_SCRIPTS_DIR}"/package.tar.gz

tar zcvf "${AWS_SCRIPTS_DIR}"/package.tar.gz .
