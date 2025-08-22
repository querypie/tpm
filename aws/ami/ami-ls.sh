#!/usr/bin/env bash

function list_ami_images() {
  local owners=$1 name=${2:-}

  printf "Name\tImageId\tState\tCreationDate\tDescription\tArch\tVType\tDevice\n"
  # Run the AWS CLI command and capture output into tmp_file
  aws ec2 describe-images \
    --owners "${owners}" \
    --filters "Name=name,Values=${name}*" \
    --query 'Images[][Name, ImageId, State, CreationDate, Description, Architecture, VirtualizationType, BlockDeviceMappings[0].DeviceName]' \
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
  marketplace)
    owners="679593333241" # AWS Marketplace
    ;;
  redhat)
    owners="309956199498" # Red Hat Enterprise Linux
    ;;
  rocky)
    owners="792107900819" # Rocky Linux
    ;;
  canonical)
    owners="099720109477" # Canonical
    ;;
  *)
    cat <<EOF
Usage: $0 [self|marketplace|redhat|rocky|canonical] [name]

EXAMPLES:
  $0 self querypie
  $0 rocky Rocky-8-
EOF
    exit 1
    ;;
  esac

  list_ami_images "${owners}" "${name}"
}

main "$@"
