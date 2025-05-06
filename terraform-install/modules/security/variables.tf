variable "vpc_id" {
  description = "ID of the VPC where resources will be created"
  type        = string
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

variable "lb_allowed_cidr_blocks" {
  description = "List of CIDR blocks that are allowed to access the resources"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "create_lb" {
  description = "Whether to use a load balancer"
  type        = bool
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

variable "products" {
  description = "List of products to enable (DAC, SAC, KAC, WAC)"
  type        = string
}

variable "agentless_proxy_ports" {
  description = "Range of ports for agentless proxy (format: '40000 - 40010')"
  type        = string
}
