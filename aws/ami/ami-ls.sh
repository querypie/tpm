#!/usr/bin/env bash

set -o nounset -o errexit -o errtrace -o pipefail

BOLD_CYAN="\e[1;36m"
RESET="\e[0m"

function log::do() {
  local line_no
  line_no=$(caller | awk '{print $1}')
  # shellcheck disable=SC2064
  trap "log::error 'Failed to run at line $line_no: $*'" ERR
  printf "%b+ %s%b\n" "$BOLD_CYAN" "$*" "$RESET" 1>&2
  "$@"
}

function list_ami_images() {
  local owners=$1 name=${2:-}

  printf "Name\tImageId\tState\tCreationDate\tDescription\tArch\tVType\tDevice\n"
  # Run the AWS CLI command and capture output into tmp_file
  log::do aws ec2 describe-images \
    --owners "${owners}" \
    --filters "Name=name,Values=${name}*" \
    --query 'sort_by(Images,&CreationDate)[::-1].[Name, ImageId, State, CreationDate, Description, Architecture, VirtualizationType, BlockDeviceMappings[0].DeviceName]' \
    --output text |
    sed -e 's/\bNone\b/-/g' |
    column -t -s $'\t'
}

function main() {
  local owner=${1:-self} name=${2:-} owners
  case "$owner" in
  self)
    owners="self"
    ;;
  aws-marketplace)
    owners="679593333241" # AWS Marketplace
    ;;
  redhat)
    owners="309956199498" # Red Hat Enterprise Linux
    ;;
  rocky)
    owners="792107900819" # Rocky Linux
    ;;
  centos)
    owners="125523088429" # CentOS Stream and Fedora
    ;;
  canonical)
    owners="099720109477" # Canonical
    ;;
  --help | -h | help | -*)
    cat <<EOF
Usage: $0 [self|aws-marketplace|redhat|rocky|centos|canonical] [name]

EXAMPLES:
  $0 self querypie
  $0 rocky Rocky-8-
EOF
    exit 1
    ;;
  *)
    owners="$owner"
    ;;
  esac

  list_ami_images "${owners}" "${name}"
}

main "$@"
