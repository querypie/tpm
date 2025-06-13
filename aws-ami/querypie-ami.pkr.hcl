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
variable "querypie_version" {
  type        = string
  default     = "10.3.0"
  description = "Version of QueryPie to install"
}

variable "ami_name_prefix" {
  type        = string
  default     = "querypie"
  description = "Prefix for AMI name"
}

variable "aws_region" {
  type        = string
  default     = "ap-northeast-2"
  description = "AWS region to build AMI"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type for building"
}

variable "ssh_username" {
  type        = string
  default     = "ec2-user"
  description = "SSH username for Amazon Linux 2023"
}

# Local variables
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  ami_name = "${var.ami_name_prefix}-${var.querypie_version}-${local.timestamp}"
}

# Data source for latest Amazon Linux 2023 AMI
data "amazon-ami" "amazon-linux-2023" {
  filters = {
    name                = "al2023-ami-*-x86_64"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners = ["amazon"]
  region      = var.aws_region
}

# Source configuration
source "amazon-ebs" "amazon-linux-2023" {
  ami_name      = local.ami_name
  instance_type = var.instance_type
  region        = var.aws_region

  source_ami = data.amazon-ami.amazon-linux-2023.id

  ssh_username = var.ssh_username

  # EBS configuration
  ebs_optimized = true
  ena_support   = true
  sriov_support = true

  # Root volume configuration
  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 30
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
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

  # Tags
  tags = {
    Name        = local.ami_name
    Environment = "production"
    OS          = "Amazon Linux 2023"
    BuildDate   = local.timestamp
    BuildTool   = "Packer"
    BaseAMI     = data.amazon-ami.amazon-linux-2023.id
  }

  # Snapshot tags
  snapshot_tags = {
    Name        = "${local.ami_name}-snapshot"
    Environment = "production"
    BuildDate   = local.timestamp
  }
}

# Build configuration
build {
  name = "build-querypie-ami"
  sources = [
    "source.amazon-ebs.amazon-linux-2023"
  ]

  provisioner "shell" {
    inline = [
      "set -o xtrace",
      "cloud-init status --wait",
      # Now this EC2 instance is ready for more software installation.

      "# System updates",
      "sudo dnf update -y",
      "sudo dnf upgrade -y",

      "# Installing essential packages...",
      "sudo dnf install -y docker",
      "sudo usermod -aG docker ${var.ssh_username}",
    ]
  }

  # Install QueryPie Deployment Package
  provisioner "shell" {
    inline = [
      "set -o xtrace",
      "pwd",
      "curl -L https://dl.querypie.com/releases/compose/setup.sh -o setup.sh",
      "QP_VERSION=${var.querypie_version} bash setup.sh",
      "[[ -d ~/.docker ]] || mkdir -p -m 700 ~/.docker",
    ]
  }

  # Setup docker environment file
  provisioner "shell" {
    environment_vars = [
      "SOURCE_FILE=querypie/${var.querypie_version}/compose-env",
    ]
    script = "scripts/init-compose-env.sh"
  }

  # Setup .docker/config.json for Docker registry authentication
  provisioner "file" {
      source      = "docker-config.json"
      destination = ".docker/config.json"
  }

  # Pull QueryPie Docker Images
  provisioner "shell" {
    inline = [
      "set -o xtrace",
      "find ~ -ls", # TODO(JK): Debugging purpose, remove later
      "cd querypie/${var.querypie_version}",
      "ln -s compose-env .env",
      "docker-compose pull app tools mysql redis --quiet",
      "docker image ls",
      "docker container ls --all",
    ]
  }

  # Final cleanup
  provisioner "shell" {
    inline = [
      "echo '# Performing final cleanup...'",
      "set -o xtrace",
      "find ~ -ls", # TODO(JK): Debugging purpose, remove later
      "rm ~/.docker/config.json",
      "sudo dnf clean all",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "history -c",
      "cat /dev/null > ~/.bash_history",
      "sudo rm -f /root/.bash_history",
      "sudo find /var/log -type f -exec truncate -s 0 {} \\;",
      "echo 'Cleanup completed'"
    ]
  }

  # Generate manifest
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
    custom_data = {
      build_time = local.timestamp
      base_ami   = data.amazon-ami.amazon-linux-2023.id
    }
  }
}
