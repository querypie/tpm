variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-northeast-2"
}

variable "os_type" {
  description = "Operating system type for the EC2 instance (amazon_linux, ubuntu, redhat)"
  type        = string
  default     = "amazon_linux"
}

variable "ami" {
  description = "AMI ID map by region"
  type        = map(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "private_ip" {
  description = "Private IP address for the EC2 instance"
  type        = string
  default     = ""
}

variable "create_new_key_pair" {
  description = "Whether to create a new key pair"
  type        = bool
  default     = false
}

variable "team" {
  description = "Team name for resource tagging"
  type        = string
}

variable "owner" {
  description = "Owner name for resource tagging"
  type        = string
}

variable "project" {
  description = "Project name for resource tagging"
  type        = string
}

variable "security_group_id" {
  description = "ID of the security group to attach to the EC2 instance"
  type        = string
}

variable "iam_instance_profile_name" {
  description = "Name of the IAM instance profile to attach to the EC2 instance"
  type        = string
}

variable "compose_env" {
  description = "Map of QueryPie versions to compose environment template files"
  type        = map(string)
}

variable "querypie_version" {
  description = "Version of QueryPie to deploy"
  type        = string
}

variable "create_lb" {
  description = "Whether to use a load balancer"
  type        = bool
}

variable "querypie_domain_name" {
  description = "Domain name for QueryPie"
  type        = string
  default     = ""
}

variable "querypie_proxy_domain_name" {
  description = "Domain name for QueryPie proxy"
  type        = string
  default     = ""
}

variable "db_host" {
  description = "Database host"
  type        = string
  default     = ""
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = ""
}

variable "db_password" {
  description = "Database password"
  type        = string
  default     = ""
}

variable "redis_nodes" {
  description = "Redis nodes (format: 'host:port' or 'host1:port1,host2:port2' for cluster mode)"
  type        = string
  default     = ""
}

variable "redis_password" {
  description = "Redis password"
  type        = string
  default     = ""
}

variable "redis_connection_mode" {
  description = "Redis connection mode (STANDALONE or CLUSTER)"
  type        = string
  default     = "STANDALONE"
}

variable "querypie_crt" {
  description = "Path to the QueryPie certificate file"
  type        = string
}

variable "docker_registry_credential_file" {
  description = "Path to the Docker registry credential file"
  type        = string
  default     = ".docker-config.json"
}

variable "userdata" {
  description = "Map of QueryPie versions to userdata script template files"
  type        = map(string)
}

variable "use_external_db" {
  description = "Whether to use an external database"
  type        = bool
  default     = false
}

variable "use_external_redis" {
  description = "Whether to use an external Redis"
  type        = bool
  default     = false
}

variable "ec2_block_device_volume_size" {
  description = "Size of the EC2 root block device in GB"
  type        = string
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
