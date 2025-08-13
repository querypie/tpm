#!/usr/bin/env bash
set -o nounset -o errexit -o xtrace

# Local Archive Script
# This script prepares the testing environment by creating a package archive and copying setup script to home directory.
#
# This script creates ~/package.tar.gz file for setup.v2.sh in local development environment.
# Purpose:
# - To test setup.v2.sh
# - To test configuration files in compose/universal/

SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

[[ -f ~/package.tar.gz ]] && rm -f ~/package.tar.gz

pushd "$SCRIPT_DIR/universal"
git pull --rebase
tar zcvf ~/package.tar.gz .


[[ -f ~/setup.v2.sh ]] && rm -f ~/setup.v2.sh
[[ -f ../../aws/scripts/setup.v2.sh ]] &&
  cp ../../aws/scripts/setup.v2.sh ~/setup.v2.sh
