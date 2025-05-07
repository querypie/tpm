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

variable "instance_id" {
  description = "ID of the EC2 instance to attach to the target groups"
  type        = string
}

variable "create_lb" {
  description = "Whether to use a load balancer"
  type        = bool
}


variable "products" {
  description = "List of products to enable (DAC, SAC, KAC, WAC)"
  type        = string
}

variable "agentless_proxy_ports" {
  description = "Range of ports for agentless proxy (format: '40000 - 40010')"
  type        = string
}


variable "vpc_id" {
  description = "ID of the VPC where resources will be created"
  type        = string
}
