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

variable "docker_auth" {
  type        = string
  description = "Base64-encoded Docker registry authentication (username:password)"
  # No default value for security reasons, must be provided at runtime
}

# Local variables
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  ami_name = "QueryPie-Suite-Installer-${local.timestamp}"

  region = "ap-northeast-2"
  instance_type = "t3.xlarge" # Use t3.xlarge to accelerate the build process
  ssh_username = "ubuntu" # SSH username for Ubuntu 24.04

  common_tags = {
    CreatedBy = "Packer"
    Owner     = "Ubuntu24.04-Installer"
    Purpose   = "Automated QueryPie Installer"
    BuildDate = local.timestamp
    Version   = var.querypie_version
  }

  instance_tags = merge(
    local.common_tags,
    {
      Name = "Ubuntu24.04-Installer-${var.querypie_version}"
    }
  )
}

# Data source for latest Ubuntu 24.04 LTS AMI
# data : Keyword to begin a data source block
# amazon-ami : Type of data source, or plugin name
# ubuntu-24-04 : Name of the data source
data "amazon-ami" "ubuntu-24-04" {
  # For detailed information of the AMI:
  # `aws ec2 describe-images --image-ids ami-0662f4965dfc70aca`
  filters = {
    name                = "ubuntu/images/*/ubuntu-noble-24.04-amd64-server-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
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

  region        = local.region
  instance_type = local.instance_type
  ssh_username = local.ssh_username

  # EBS configuration
  ebs_optimized = true
  ena_support   = true
  sriov_support = true

  # Root volume configuration
  launch_block_device_mappings {
    # device_name is confirmed from: `aws ec2 describe-images --image-ids ami-0662f4965dfc70aca`
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
      "cloud-init status --wait",
      # Now this EC2 instance is ready for more software installation.
      "# Show the current process list and group information",
      "ps ux", "id -Gn",
      "# Installing essential packages...",
      "sudo apt -qq update",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /tmp/docker.asc",
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "sudo install -m 0644 /tmp/docker.asc /etc/apt/keyrings/docker.asc",
      "echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable' | sudo tee /etc/apt/sources.list.d/docker.list",
      "sudo apt -qq update",
      "DEBIAN_FRONTEND=noninteractive sudo -E apt-get -y -qq install docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-ce-rootless-extras docker-buildx-plugin docker-model-plugin",

      "sudo systemctl start docker",
      "sudo systemctl enable docker",

      "sudo usermod -aG docker ${local.ssh_username}",
    ]
  }

  # Force SSH reconnection to ensure fresh session
  provisioner "shell" {
    inline_shebang = "/bin/bash -ex"
    expect_disconnect = true # It will logout at the end of this provisioner.
    inline = [
      "echo 'Forcing SSH reconnection...'",
      "killall sshd",
    ]
  }

  # Setup .docker/config.json for Docker registry authentication
  provisioner "file" {
    source      = "docker-config.tmpl.json"
    destination = "/tmp/docker-config.tmpl.json"
  }
  provisioner "shell" {
    inline_shebang = "/bin/bash -ex"
    environment_vars = [
      "DOCKER_AUTH=${var.docker_auth}"
    ]
    inline = [
      "ps ux", "id -Gn",
      "[ -d ~/.docker ] || mkdir -p -m 700 ~/.docker",
      "sed 's/<base64-encoded-username:password>/${var.docker_auth}/g' /tmp/docker-config.tmpl.json > ~/.docker/config.json",
      "chmod 600 ~/.docker/config.json"
    ]
  }

  # Install scripts such as setup.v2.sh
  provisioner "file" {
    source      = "scripts/"
    destination = "/tmp/"
  }
  provisioner "shell" {
    inline_shebang = "/bin/bash -ex"
    inline = [
      "sudo install -m 755 /tmp/setup.v2.sh /usr/local/bin/setup.v2.sh",
    ]
  }

  # Install QueryPie Deployment Package
  provisioner "shell" {
    inline_shebang = "/bin/bash -ex"
    inline = [
      "setup.v2.sh --install ${var.querypie_version}",
      "setup.v2.sh --verify-installation",
    ]
  }

  # Final cleanup
  provisioner "shell" {
    inline_shebang = "/bin/bash -ex"
    inline = [
      "echo '# Performing final cleanup...'",
      "rm ~/.docker/config.json",
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
      querypie_version = var.querypie_version
    }
  }
}
