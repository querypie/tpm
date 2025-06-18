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

variable "docker_auth" {
  type        = string
  description = "Base64-encoded Docker registry authentication (username:password)"
  # No default value for security reasons, must be provided at runtime
}

# Local variables
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  ami_name = "${var.ami_name_prefix}-${var.querypie_version}-${local.timestamp}"
  region   = "ap-northeast-2"
  instance_type = "t3.xlarge" # Use t3.xlarge to accelerate the build process
  ssh_username = "ec2-user" # SSH username for Amazon Linux 2023

  common_tags = {
    CreatedBy = "Packer"
    Owner     = "AMI-Builder"
    Purpose   = "Automated QueryPie AMI Build"
    BuildDate = local.timestamp
    Version   = var.querypie_version
  }

  instance_tags = merge(
    local.common_tags,
    {
      Name = "AMI-Builder-${local.ami_name}"
    }
  )
  ami_tags = merge(
    local.common_tags,
    {
      Name    = local.ami_name
      OS      = "Amazon Linux 2023"
      BaseAMI = data.amazon-ami.amazon-linux-2023.id
    }
  )
  snapshot_tags = merge(
    local.common_tags,
    {
      Name        = "${local.ami_name}-snapshot"
      Description = "Snapshot of QueryPie AMI built on ${local.timestamp}"
    }
  )
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
  region      = local.region
}

# Builder Configuration
source "amazon-ebs" "amazon-linux-2023" {
  ami_name      = local.ami_name
  instance_type = local.instance_type
  region        = local.region
  ssh_username  = local.ssh_username

  source_ami = data.amazon-ami.amazon-linux-2023.id

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

  # Tags of the AMI created
  tags = local.ami_tags

  # Tags of the snapshot from VM
  snapshot_tags = local.snapshot_tags
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
      "sudo usermod -aG docker ${local.ssh_username}",
    ]
  }

  # Install QueryPie Deployment Package
  provisioner "shell" {
    inline = [
      "set -o xtrace",
      "pwd",
      "curl -L https://dl.querypie.com/releases/compose/setup.sh -o setup.sh",
      "QP_VERSION=${var.querypie_version} bash setup.sh",

      # Create a symlink, .env for compose-env.
      "cd querypie/${var.querypie_version}",
      "ln -s compose-env .env",
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
    source      = "docker-config.tmpl.json"
    destination = "/tmp/docker-config.tmpl.json"
  }
  provisioner "shell" {
    environment_vars = [
      "DOCKER_AUTH=${var.docker_auth}"
    ]
    inline = [
      "set -o xtrace",
      "[[ -d ~/.docker ]] || mkdir -p -m 700 ~/.docker",
      "sed 's/<base64-encoded-username:password>/${var.docker_auth}/g' /tmp/docker-config.tmpl.json > ~/.docker/config.json",
      "chmod 600 ~/.docker/config.json"
    ]
  }

  # Run mysql, redis containers
  provisioner "shell" {
    inline = [
      "set -o xtrace",
      "cd querypie/${var.querypie_version}",
      "docker-compose pull --quiet mysql redis",
      "docker-compose --profile database up --detach",
    ]
  }

  # Run querypie-tools container
  provisioner "shell" {
    inline = [
      "set -o xtrace",

      # Create a swap file for the tools container to allow enough memory
      "sudo dd if=/dev/zero of=/swapfile bs=1M count=4096", # 4 GiB swap file
      "sudo chmod 600 /swapfile",
      "sudo mkswap /swapfile",
      "sudo swapon /swapfile",

      # Run querypie-tools container
      "cd querypie/${var.querypie_version}",
      "docker-compose pull --quiet tools",
      "docker-compose --profile tools up --detach",
      "docker container ls --all",
    ]
  }

  # Wait for the tools container to be ready
  provisioner "shell" {
    script = "scripts/tools-readyz"
  }

  # Migrate the database from querypie-tools container
  provisioner "shell" {
    inline = [
      "set -o xtrace",

      # Run containers, and populate the MySQL database
      "cd querypie/${var.querypie_version}",
      # Save long output of migrate.sh as querypie-migrate.log
      "docker exec querypie-tools-1 /app/script/migrate.sh runall >~/querypie-migrate.log 2>&1",
      # Run migrate.sh again to ensure the migration is completed properly
      "docker exec querypie-tools-1 /app/script/migrate.sh runall",
      "docker-compose --profile tools down",
    ]
  }

  # Create querypie-app container, but do not start it
  provisioner "shell" {
    inline = [
      "set -o xtrace",
      "cd querypie/${var.querypie_version}",
      "docker-compose pull --quiet app",
      "docker-compose --profile querypie up --no-start --detach",
      "docker container ls --all",
    ]
  }

  # Setup querypie-first-boot.service
  provisioner "file" {
    source      = "querypie-first-boot.service"
    destination = "/tmp/querypie-first-boot.service"
  }
  provisioner "shell" {
    inline = [
      "set -o xtrace",
      "sudo install -m 644 /tmp/querypie-first-boot.service /etc/systemd/system/querypie-first-boot.service",
      "sudo systemctl enable querypie-first-boot.service",
      "sudo systemctl daemon-reload",
      # Please note that this service will run only once, at the first boot of the AMI.
      # You can check the status of this service using `systemctl status querypie-first-boot.service`,
      # after the AMI is launched.
      # Unless this service is running, the QueryPie application will not be started automatically.
    ]
  }

  # Final cleanup
  provisioner "shell" {
    inline = [
      "echo '# Performing final cleanup...'",
      "set -o xtrace",
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
