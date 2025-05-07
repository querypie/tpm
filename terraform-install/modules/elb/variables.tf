# ELB module variables.tf

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "team" {
  description = "Team name"
  type        = string
}

variable "owner" {
  description = "Owner name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "lb_allowed_cidr_blocks" {
  description = "List of CIDR blocks that are allowed to access the resource"
  type        = list(string)
}

variable "create_root_domain" {
  description = "Boolean to control the creation of root domain"
  type        = bool
  default     = false
}

variable "create_querypie_domain" {
  description = "Boolean to control the creation of QueryPie domain"
  type        = bool
  default     = false
}

variable "root_domain_name" {
  description = "Root domain name"
  type        = string
}

variable "querypie_domain_name" {
  description = "QueryPie domain name"
  type        = string
}

variable "querypie_proxy_domain_name" {
  description = "QueryPie proxy domain name"
  type        = string
}

variable "aws_route53_zone_id" {
  description = "AWS Route53 zone ID"
  type        = string
}

variable "aws_acm_certificate_arn" {
  description = "AWS ACM certificate ARN"
  type        = string
}

variable "products" {
  description = "List of products to enable (DAC, SAC, KAC, WAC)"
  type        = string
}

variable "agentless_proxy_ports" {
  description = "Range of ports for agentless proxy (format: '40000 - 40010')"
  type        = string
}


variable "instance_id" {
  description = "ID of the EC2 instance to attach to the target groups"
  type        = string
  default     = ""
}

variable "alb_security_group_id" {
  description = "ID of the security group for the ALB"
  type        = string
  default     = ""
}

variable "nlb_security_group_id" {
  description = "ID of the security group for the NLB"
  type        = string
  default     = ""
}

variable "lb_subnet_ids" {
  description = "List of subnet IDs to attach to the load balancers"
  type        = list(string)
  default     = []
}

variable "tg_80_arn" {
  description = "ARN of the target group for port 80"
  type        = string
  default     = ""
}

variable "tg_9000_arn" {
  description = "ARN of the target group for port 9000"
  type        = string
  default     = ""
}

variable "tg_6443_arn" {
  description = "ARN of the target group for port 6443"
  type        = string
  default     = ""
}

variable "tg_7447_arn" {
  description = "ARN of the target group for port 7447"
  type        = string
  default     = ""
}

variable "tg_agentless_proxy_ports_arns" {
  description = "ARNs of the target groups for agentless proxy ports"
  type        = map(string)
  default     = {}
}
