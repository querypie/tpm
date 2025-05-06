locals {
  # Define OS-specific settings based on os_type
  os_user     = var.os_type == "ubuntu" ? "ubuntu" : "ec2-user"
  os_home_dir = var.os_type == "ubuntu" ? "/home/ubuntu" : "/home/ec2-user"
}

resource "aws_instance" "querypie_ec2" {
  ami                    = var.ami[var.aws_region]
  instance_type          = var.instance_type
  private_ip             = var.private_ip != "" ? var.private_ip : null
  key_name               = var.create_new_key_pair ? aws_key_pair.querypie_key[0].key_name : "${var.team}-${var.owner}-${var.project}-key"
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.iam_instance_profile_name

  metadata_options {
    http_tokens = "required"
  }

  provisioner "file" {
    content = templatefile(lookup(var.compose_env, var.querypie_version, lookup(var.compose_env, "default", "compose-env.tpl")), {
      PRIVATE_IP            = self.private_ip,
      QUERYPIE_HOST         = var.create_lb ? "https://${var.querypie_domain_name}" : self.public_ip,
      QUERYPIE_PROXY_HOST   = var.create_lb ? var.querypie_proxy_domain_name : "",
      QUERYPIE_VERSION      = var.querypie_version
      DB_HOST               = var.use_external_db ? var.db_host : self.private_ip
      DB_USERNAME           = var.use_external_db ? var.db_username : "querypie"
      DB_PASSWORD           = var.use_external_db ? var.db_password : "Querypie1!"
      REDIS_CONNECTION_MODE = var.use_external_redis ? var.redis_connection_mode : "STANDALONE"
      REDIS_NODES           = var.use_external_redis ? var.redis_nodes : "${self.private_ip}:6379"
      REDIS_PASSWORD        = var.use_external_redis ? var.redis_password : ""
      AGENT_SECRET          = var.agent_secret != "" ? var.agent_secret : random_id.agent_secret.hex
      KEY_ENCRYPTION_KEY    = var.key_encryption_key != "" ? var.key_encryption_key : random_id.key_encryption_key.b64_std
    })
    destination = "${local.os_home_dir}/compose-env"
  }

  provisioner "file" {
    content     = file(var.querypie_crt)
    destination = "${local.os_home_dir}/license.crt"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = local.os_user
    private_key = var.create_new_key_pair ? tls_private_key.querypie_key[0].private_key_pem : file("${var.team}-${var.owner}-${var.project}-key.pem")
  }

  user_data = templatefile(lookup(var.userdata, var.querypie_version, lookup(var.userdata, "default", "userdata-script.tpl")), {
    QUERYPIE_VERSION      = var.querypie_version,
    DOCKER_CONFIG         = file(var.docker_registry_credential_file),
    QUERYPIE_PROXY_HOST   = var.create_lb ? var.querypie_proxy_domain_name : ""
    USE_EXTERNALDB        = var.use_external_db ? "1" : "0"
    USE_EXTERNALREDIS     = var.use_external_redis ? "1" : "0"
    DB_HOST               = var.db_host
    DB_NAME               = "querypie"
    DB_USERNAME           = var.db_username
    DB_PASSWORD           = var.db_password
    REDIS_CONNECTION_MODE = var.redis_connection_mode
    REDIS_NODES           = var.redis_nodes
    REDIS_PASSWORD        = var.redis_password
    OS_TYPE               = var.os_type
    OS_USER               = local.os_user
    OS_HOME_DIR           = local.os_home_dir
  })

  root_block_device {
    volume_size           = var.ec2_block_device_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name  = "${var.team}-${var.owner}-${var.project}-ec2"
    Team  = var.team
    Owner = var.owner
  }
}

# Generate a private key using the RSA algorithm.
resource "tls_private_key" "querypie_key" {
  count     = var.create_new_key_pair ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create a key pair file using the private key.
resource "aws_key_pair" "querypie_key" {
  count      = var.create_new_key_pair ? 1 : 0
  key_name   = "${var.team}-${var.owner}-${var.project}-key"
  public_key = tls_private_key.querypie_key[count.index].public_key_openssh
}

# Generate a key file and download it locally.
resource "local_file" "ssh_key" {
  count    = var.create_new_key_pair ? 1 : 0
  filename = "${aws_key_pair.querypie_key[0].key_name}.pem"
  content  = tls_private_key.querypie_key[0].private_key_pem
}

# Generate a random agent secret for QueryPie
resource "random_id" "agent_secret" {
  byte_length = 16
}

# Generate a random key encryption key for QueryPie
resource "random_id" "key_encryption_key" {
  byte_length = 32
}
