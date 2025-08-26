#!/usr/bin/env bash
set -o nounset -o errexit -o xtrace

# Local Archive Script
# This script prepares the testing environment by creating a package archive and copying the setup script to a home directory.
#
# This script creates the ~/offline / package.tar.gz file for setup.v2.sh in a local development environment.
# Purpose:
# - To test setup.v2.sh
# - To test configuration files in compose/universal/

SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

if [[ -d ~/offline ]]; then
  [[ -f ~/offline/package.tar.gz ]] && rm -f ~/offline/package.tar.gz
else
  mkdir -p ~/offline
fi

pushd "$SCRIPT_DIR/universal"
git pull --rebase
tar zcvf ~/offline/package.tar.gz .

[[ -f ~/setup.v2.sh ]] && rm -f ~/setup.v2.sh
[[ -f ../../aws/scripts/setup.v2.sh ]] &&
  cp ../../aws/scripts/setup.v2.sh ~/setup.v2.sh
