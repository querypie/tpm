variable "aws_region" {
  default = "ap-northeast-2"
}

variable "aws_profile" {
  description = "AWS profile to use for authentication"
  type        = string
  default     = ""
}

variable "vpc_id" {
  type    = string
  default = "vpc-0208ffab6a1e1bcd5"
}

variable "os_type" {
  description = "Operating system type for the EC2 instance (amazon_linux, ubuntu, redhat)"
  type        = string
  default     = "amazon_linux"

  validation {
    condition     = contains(["amazon_linux", "ubuntu", "redhat"], var.os_type)
    error_message = "The os_type must be one of: amazon_linux, ubuntu, redhat."
  }
}

variable "ami" {
  description = "AMI IDs for different OS types by region"
  type        = map(map(string))
  default = {
    amazon_linux = {
      ap-northeast-2 = "ami-0eb302fcc77c2f8bd" # Amazon Linux 2023 AMI 2023.7.20250414.0 x86_64 HVM kernel-6.1
    }
    ubuntu = {
      ap-northeast-2 = "ami-0d5bb3742db8fc264" # Ubuntu Server 24.04 LTS (HVM),EBS General Purpose (SSD) Volume Type
    }
    redhat = {
      ap-northeast-2 = "ami-0ce95bc31da06c4a5" # Red Hat Enterprise Linux version 9 (HVM), EBS General Purpose (SSD) Volume Type
    }
  }
}

variable "ec2_block_device_volume_size" {
  default = "50"
}

variable "lb_allowed_cidr_blocks" {
  description = "List of CIDR blocks that are allowed to access the resource"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "organization" {
  type        = string
  description = "Oragnization Name"
}

variable "team" {
  type        = string
  description = "Team Name"
}

variable "owner" {
  type        = string
  description = "Owner Name"
}

variable "project" {
  type        = string
  description = "Project Name"
}

variable "querypie_version" {
  type        = string
  default     = "9.19.0"
  description = "QueryPie Version"
}

variable "compose_env" {
  type = map(string)
  default = {
    "9.20.0"  = "compose-env-9.20.tpl"
    "9.20.1"  = "compose-env-9.20.tpl"
    "10.0.0"  = "compose-env-10.0.0.tpl"
    "default" = "compose-env.tpl"
  }
}

variable "instance_type" {
  type    = string
  default = "m5.large"
}

variable "userdata" {
  type = map(string)
  default = {
    "9.20.0"  = "userdata-script-9.20.0.tpl"
    "9.20.1"  = "userdata-script-9.20.1.tpl"
    "10.0.0"  = "userdata-script-10.0.0.tpl"
    "default" = "userdata-script.tpl"
  }
}


variable "private_ip" {
  description = "Existing private IP address"
  type        = string
  default     = ""
}

variable "create_new_key_pair" {
  description = "Flag to determine if a new key pair should be created"
  type        = bool
  default     = false
}

variable "querypie_crt" {
  type    = string
  default = ".license.crt"
}

variable "docker_registry_credential_file" {
  description = "Path to the Docker registry credential file"
  type        = string
  default     = ".docker-config.json"
}

variable "products" {
  description = "List of products to enable (DAC, SAC, KAC, WAC)"
  type        = string
  default     = "DAC, SAC, KAC, WAC"
}

variable "agentless_proxy_ports" {
  description = "Range of ports for agentless proxy (format: '40000 - 40010')"
  type        = string
  default     = "40000 - 40100"
}


variable "create_lb" {
  description = "Indicates whether to use a domain for the resources. If set to true, domain-related settings will be configured."
  type        = bool
}

variable "querypie_domain_name" {
  type    = string
  default = ""
}

variable "querypie_proxy_domain_name" {
  type    = string
  default = ""
}

variable "use_external_db" {
  description = "Indicates whether to use an external database."
  type        = bool
  default     = false
}

variable "use_external_redis" {
  description = "Indicates whether to use an external Redis."
  type        = bool
  default     = false
}

variable "db_host" {
  type    = string
  default = ""
}

variable "db_username" {
  type    = string
  default = ""
}

variable "db_password" {
  type    = string
  default = ""
}

variable "redis_nodes" {
  type    = string
  default = ""
}

variable "redis_password" {
  type    = string
  default = ""
}

variable "redis_connection_mode" {
  description = "Redis connection mode (STANDALONE or CLUSTER)"
  type        = string
  default     = "STANDALONE"

  validation {
    condition     = contains(["STANDALONE", "CLUSTER"], var.redis_connection_mode)
    error_message = "The redis_connection_mode must be one of: STANDALONE, CLUSTER."
  }
}

variable "agent_secret" {
  description = "Secret key for encrypting communication between QueryPie client agents and QueryPie"
  type        = string
  default     = ""
}

variable "key_encryption_key" {
  description = "Secret key used to encrypt sensitive information, such as database connection strings and SSH private keys"
  type        = string
  default     = ""
}

variable "aws_route53_zone_id" {
  description = "AWS Route53 zone ID for creating DNS records"
  type        = string
  default     = ""
}

variable "aws_acm_certificate_arn" {
  description = "AWS ACM certificate ARN for HTTPS listeners"
  type        = string
  default     = ""
}

variable "lb_subnet_ids" {
  description = "List of subnet IDs to attach to the load balancers"
  type        = list(string)
  default     = []
}
