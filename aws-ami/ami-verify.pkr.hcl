# This file is to create a QueryPie AMI using Packer for AWS Marketplace.

packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# Variables
variable "source_ami" {
  type        = string
  description = "ID of the AMI to verify"
}

# Local variables
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  source_ami = var.source_ami
  ami_name   = "QueryPie-Suite-Verification-${local.timestamp}"

  region = "ap-northeast-2"
  instance_type = "t3.xlarge" # Use t3.xlarge to accelerate the build process
  ssh_username = "ec2-user" # SSH username for Amazon Linux 2023

  common_tags = {
    CreatedBy = "Packer"
    Owner     = "AMI-Verifier"
    Purpose   = "Automated QueryPie AMI Verification"
    BuildDate = local.timestamp
  }

  instance_tags = merge(
    local.common_tags,
    {
      Name = "AMI-Verifier-${local.source_ami}"
    }
  )
}

# Builder Configuration
# source : Keyword to begin a source block
# amazon-ebs : Type of source, or plugin name
# querypie-suite : Name of the source block
source "amazon-ebs" "querypie-suite" {
  skip_create_ami = true
  source_ami = local.source_ami
  ami_name   = local.ami_name

  region        = local.region
  instance_type = local.instance_type
  ssh_username = local.ssh_username

  # EBS configuration
  ebs_optimized = true
  ena_support   = true
  sriov_support = true

  # Root volume configuration
  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 32
    volume_type           = "gp3"
    iops = 16000 # Max: 16000 IOPS for gp3
    throughput = 1000  # Max: 1000 MiB/s throughput
    delete_on_termination = true
    encrypted             = true
  }

  # Instance metadata options
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Security group configuration
  temporary_security_group_source_cidrs = ["0.0.0.0/0"]

  # Tags of the EC2 instance used for building the AMI
  run_tags = local.instance_tags
}

# Build configuration
build {
  name = "verify-querypie-ami"
  sources = [
    "source.amazon-ebs.querypie-suite"
  ]

  provisioner "shell" {
    inline = [
      "set -o xtrace",
      "cloud-init status --wait",
      # Now this EC2 instance is ready for more software installation.
    ]
  }

  # Verify QueryPie installation
  provisioner "shell" {
    inline = [
      "set -o xtrace",
      "setup.v2.sh --verify-installation || true",
    ]
  }
}
