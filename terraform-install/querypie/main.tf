# Provider configuration
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null
}

# Security module
module "security" {
  source = "../modules/security"

  vpc_id                 = var.vpc_id
  team                   = var.team
  owner                  = var.owner
  project                = var.project
  lb_allowed_cidr_blocks = var.lb_allowed_cidr_blocks
  create_lb              = var.create_lb
  use_external_db        = var.use_external_db
  use_external_redis     = var.use_external_redis
  products               = var.products
  agentless_proxy_ports  = var.agentless_proxy_ports
}

# IAM module
module "iam" {
  source = "../modules/iam"

  team     = var.team
  owner    = var.owner
  project  = var.project
  products = var.products
}

# EC2 module
module "ec2" {
  source = "../modules/ec2"

  aws_region                   = var.aws_region
  os_type                      = var.os_type
  ami                          = var.ami[var.os_type]
  instance_type                = var.instance_type
  private_ip                   = var.private_ip
  create_new_key_pair          = var.create_new_key_pair
  team                         = var.team
  owner                        = var.owner
  project                      = var.project
  security_group_id            = module.security.security_group_id
  iam_instance_profile_name    = module.iam.instance_profile_name
  compose_env                  = var.compose_env
  querypie_version             = var.querypie_version
  create_lb                    = var.create_lb
  querypie_domain_name         = var.querypie_domain_name
  querypie_proxy_domain_name   = var.querypie_proxy_domain_name
  db_host                      = var.db_host
  db_username                  = var.db_username
  db_password                  = var.db_password
  redis_nodes                  = var.redis_nodes
  redis_password               = var.redis_password
  redis_connection_mode        = var.redis_connection_mode
  querypie_crt                 = var.querypie_crt
  docker_registry_credential_file = var.docker_registry_credential_file
  userdata                     = var.userdata
  use_external_db              = var.use_external_db
  use_external_redis           = var.use_external_redis
  ec2_block_device_volume_size = var.ec2_block_device_volume_size
  agent_secret                 = var.agent_secret
  key_encryption_key           = var.key_encryption_key
}

# Networking module
module "networking" {
  source = "../modules/networking"

  team                  = var.team
  owner                 = var.owner
  project               = var.project
  instance_id           = module.ec2.instance_id
  create_lb             = var.create_lb
  products              = var.products
  agentless_proxy_ports = var.agentless_proxy_ports
  vpc_id                = var.vpc_id
}

# ELB module - only created when create_lb is true
module "elb" {
  count  = var.create_lb ? 1 : 0
  source = "../modules/elb"

  aws_region                    = var.aws_region
  vpc_id                        = var.vpc_id
  team                          = var.team
  owner                         = var.owner
  project                       = var.project
  lb_allowed_cidr_blocks        = var.lb_allowed_cidr_blocks
  create_root_domain            = false
  create_querypie_domain        = true
  root_domain_name              = ""
  querypie_domain_name          = var.querypie_domain_name
  querypie_proxy_domain_name    = var.querypie_proxy_domain_name
  aws_route53_zone_id           = var.aws_route53_zone_id
  aws_acm_certificate_arn       = var.aws_acm_certificate_arn
  products                      = var.products
  agentless_proxy_ports         = var.agentless_proxy_ports
  instance_id                   = module.ec2.instance_id
  alb_security_group_id         = module.security.alb_security_group_id
  nlb_security_group_id         = module.security.nlb_security_group_id
  lb_subnet_ids                 = var.lb_subnet_ids
  tg_80_arn                     = module.networking.tg_80_arn
  tg_9000_arn                   = module.networking.tg_9000_arn
  tg_6443_arn                   = module.networking.tg_6443_arn
  tg_7447_arn                   = module.networking.tg_7447_arn
  tg_agentless_proxy_ports_arns = module.networking.tg_agentless_proxy_ports_arns
}
