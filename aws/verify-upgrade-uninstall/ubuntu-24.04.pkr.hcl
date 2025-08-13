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
variable "initial_version" {
  type        = string
  default     = "11.0.1"
  description = "Version of QueryPie to install"
}

variable "upgrade_version" {
  type        = string
  default     = "11.1.1"
  description = "Version of QueryPie to upgrade"
}

variable "architecture" {
  type = string
  default = "x86_64"
  description = "x86_64 | arm64"
}

variable "resource_owner" {
  type        = string
  default     = "Ubuntu24.04-Installer"
  description = "Owner of AWS Resources"
}

# Local variables
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  ami_name = "QueryPie-Suite-Installer-${local.timestamp}"

  region = "ap-northeast-2"
  ssh_username = "ubuntu" # SSH username for Ubuntu 24.04

  common_tags = {
    CreatedBy = "Packer"
    Owner     = var.resource_owner
    Purpose   = "Automated QueryPie Installer"
    BuildDate = local.timestamp
    Version   = var.initial_version
  }

  instance_tags = merge(
    local.common_tags,
    {
      Name = "Ubuntu24.04-Installer-${var.initial_version}"
    }
  )
}

# Data source for latest Ubuntu 24.04 LTS AMI
# data : Keyword to begin a data source block
# amazon-ami : Type of data source, or plugin name
# ubuntu-24-04 : Name of the data source
###
# aws ec2 describe-images --image-ids ami-0811349cae530179a
# "Name": "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-20250610"
# "Description": "Canonical, Ubuntu, 24.04, amd64 noble image"
# "Architecture": "x86_64"
# "DeviceName": "/dev/sda1"
###
# aws ec2 describe-images --image-ids ami-09ed9bca6a01cd74a
# "Name": "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-20250610"
# "Description": "Canonical, Ubuntu, 24.04, arm64 noble image"
# "Architecture": "arm64"
# "DeviceName": "/dev/sda1"
data "amazon-ami" "ubuntu-24-04" {
  filters = {
    name                = "ubuntu/images/*/ubuntu-noble-24.04-*-server-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
    architecture        = var.architecture == "arm64" ? "arm64" : "x86_64"
  }
  most_recent = true
  owners = ["099720109477"] # # Canonical's AWS Account ID
  region      = local.region
}

# Builder Configuration
# source : Keyword to begin a source block
# amazon-ebs : Type of builder, or plugin name
# ubuntu24-04-install : Name of the builder
source "amazon-ebs" "ubuntu24-04-install" {
  skip_create_ami = true
  source_ami      = data.amazon-ami.ubuntu-24-04.id
  ami_name        = local.ami_name

  region       = local.region
  ssh_username = local.ssh_username
  # ssh_private_key_file = "demo-targets.pem"
  # ssh_keypair_name = "demo-targets"

  # spot_instance_types = ["t4g.xlarge"]
  spot_instance_types = var.architecture == "arm64" ? ["t4g.xlarge"] : ["t3.xlarge"]
  spot_price = "0.09" # the maximum hourly price
  # $0.0646 for t4g.xlarge instance in ap-northeast-2
  # $0.078 for t3.xlarge instance

  # EBS configuration
  ebs_optimized = true

  # Root volume configuration
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
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
  sources = [
    "source.amazon-ebs.ubuntu24-04-install"
  ]

  provisioner "shell" {
    inline_shebang = "/bin/bash -ex"
    inline = [
      "cloud-init status --wait", # Now this EC2 instance is ready for more software installation.
    ]
  }

  provisioner "shell" {
    expect_disconnect = true # It will logout at the end of this provisioner.
    script = "../scripts/install-docker-on-ubuntu.sh"
  }

  # Install scripts such as setup.v2.sh
  provisioner "file" {
    source      = "../scripts/"
    destination = "/tmp/"
  }
  provisioner "shell" {
    inline_shebang = "/bin/bash -ex"
    inline = [
      "ps ux", "id -Gn", # Show the current process list and group information
      "sudo install -m 755 /tmp/setup.v2.sh /usr/local/bin/setup.v2.sh",
    ]
  }

  # Install QueryPie
  provisioner "shell" {
    inline_shebang = "/bin/bash -ex"
    inline = [
      "setup.v2.sh --yes --install ${var.initial_version}",
      "setup.v2.sh --verify-installation",
    ]
  }

  # Upgrade QueryPie
  provisioner "shell" {
    inline_shebang = "/bin/bash -ex"
    inline = [
      "setup.v2.sh --yes --upgrade ${var.upgrade_version}",
      "setup.v2.sh --verify-installation",
    ]
  }

  # Uninstall QueryPie
  provisioner "shell" {
    inline_shebang = "/bin/bash -ex"
    inline = [
      "setup.v2.sh --uninstall",
      "docker ps --all",
      "setup.v2.sh --verify-not-installed",
    ]
  }

  # Final cleanup
  provisioner "shell" {
    inline_shebang = "/bin/bash -ex"
    inline = [
      "echo '# Performing final cleanup...'",
      "sudo apt clean",
      "sudo apt autoremove -y",
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
      timestmap        = local.timestamp
      initial_version = var.initial_version
      upgrade_version = var.upgrade_version
    }
  }
}
