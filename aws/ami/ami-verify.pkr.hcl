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

variable "architecture" {
  type        = string
  default     = "x86_64"
  description = "Architecture of the AMI to verify"

  validation {
    condition     = contains(["x86_64", "arm64"], var.architecture)
    error_message = "Architecture must be either x86_64 or arm64."
  }
}

variable "region" {
  type        = string
  default     = "ap-northeast-2"
  description = "Region containing the AMI to verify"
}

# Local variables
locals {
  timestamp     = regex_replace(timestamp(), "[- TZ:]", "")
  source_ami    = var.source_ami
  ami_name      = "QueryPie-Suite-Verification-${local.timestamp}"
  instance_type = var.architecture == "arm64" ? "t4g.xlarge" : "t3.xlarge"

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
# amazon-ebs : Type of builder, or plugin name
# ami-verify : Name of the builder
source "amazon-ebs" "ami-verify" {
  skip_create_ami = true
  source_ami      = local.source_ami
  ami_name        = local.ami_name

  region        = var.region
  instance_type = local.instance_type
  ssh_username  = local.ssh_username
  ssh_interface = "session_manager"

  iam_instance_profile        = "ec2-session-manager"
  associate_public_ip_address = true

  subnet_filter {
    filters = {
      "default-for-az" = "true"
    }
    most_free = true
  }

  # EBS configuration
  ebs_optimized = true
  ena_support   = true

  # Root volume configuration
  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 32
    volume_type           = "gp3"
    iops = 16000 # Max: 16000 IOPS for gp3
    throughput = 1000  # Max: 1000 MiB/s throughput
    delete_on_termination = true
    # The verification volume is temporary and is not submitted to Marketplace.
    encrypted = true
  }

  # Instance metadata options
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Tags of the EC2 instance used for building the AMI
  run_tags = local.instance_tags
}

# Build configuration
build {
  sources = [
    "source.amazon-ebs.ami-verify"
  ]

  provisioner "shell" {
    inline_shebang = "/bin/bash -ex"
    inline = [
      "cloud-init status --wait",
      # Now this EC2 instance is ready for more software installation.
    ]
  }

  # Install helper scripts (install-*.sh, etc.)
  # TODO(JK): Remove this provisioner when setup.v2.sh is completed.
  provisioner "file" {
    source      = "../scripts/"
    destination = "/tmp/"
  }
  provisioner "file" {
    source      = "../../compose/setup.v2.sh"
    destination = "/tmp/setup.v2.sh"
  }
  provisioner "shell" {
    inline_shebang = "/bin/bash -ex"
    inline = [
      "sudo install -m 755 /tmp/setup.v2.sh /usr/local/bin/setup.v2.sh",
    ]
  }

  # Verify QueryPie installation
  provisioner "shell" {
    inline_shebang = "/bin/bash -ex"
    inline = [
      "setup.v2.sh --verify-installation",
    ]
  }

  # API-level AMI inspection cannot detect encrypted guest file systems.
  provisioner "shell" {
    script = "validate-image-runtime.sh"
  }

  # Generate manifest
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
    custom_data = {
      timestamp = local.timestamp
      ami_name  = local.ami_name
      region    = var.region
    }
  }
}
