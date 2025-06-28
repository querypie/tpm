#!/usr/bin/env bash

set -o xtrace

aws ec2 describe-images \
  --owners self \
  --query 'Images[*].{Name:Name,ImageId:ImageId,State:State,CreationDate:CreationDate,Description:Description,Architecture:Architecture,VirtualizationType:VirtualizationType}' \
  --output table

