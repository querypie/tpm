# ELB module main.tf

# Security groups are now passed from the security module

# Create ALB
resource "aws_lb" "querypie_alb" {
  name               = "${var.team}-${var.owner}-${var.project}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = length(var.lb_subnet_ids) > 0 ? var.lb_subnet_ids : data.aws_subnets.public.ids

  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true

  tags = {
    Name    = "${var.team}-${var.owner}-${var.project}-alb"
    Project = var.project
  }
}

# Create NLB
resource "aws_lb" "querypie_nlb" {
  name               = "${var.team}-${var.owner}-${var.project}-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = length(var.lb_subnet_ids) > 0 ? var.lb_subnet_ids : data.aws_subnets.public.ids

  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true

  tags = {
    Name    = "${var.team}-${var.owner}-${var.project}-nlb"
    Project = var.project
  }
}

# Create ALB listeners
resource "aws_lb_listener" "querypie_alb_http" {
  load_balancer_arn = aws_lb.querypie_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "querypie_alb_https" {
  load_balancer_arn = aws_lb.querypie_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.aws_acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = var.tg_80_arn
  }
}


# Parse port ranges into lists
locals {
  # Check if products contain specific products
  has_dac = can(regex("DAC", var.products))
  has_kac = can(regex("KAC", var.products))
  has_wac = can(regex("WAC", var.products))

  # Parse agentless_proxy_ports range (only for DAC)
  agentless_proxy_range = local.has_dac ? split("-", replace(var.agentless_proxy_ports, " ", "")) : []
  agentless_proxy_start = length(local.agentless_proxy_range) > 0 ? tonumber(local.agentless_proxy_range[0]) : 0
  agentless_proxy_end = length(local.agentless_proxy_range) > 1 ? tonumber(local.agentless_proxy_range[1]) : local.agentless_proxy_start
  agentless_proxy_ports = local.has_dac ? [for port in range(local.agentless_proxy_start, local.agentless_proxy_end + 1) : port] : []

  # Filter target group ARNs to only include ports in agentless_proxy_ports
  filtered_tg_arns = {
    for port, arn in var.tg_agentless_proxy_ports_arns :
    port => arn if contains(local.agentless_proxy_ports, tonumber(port))
  }
}

# Create NLB listeners for agentless proxy ports (only for DAC)
resource "aws_lb_listener" "querypie_nlb_agentless_proxy" {
  for_each = local.has_dac ? local.filtered_tg_arns : {}

  load_balancer_arn = aws_lb.querypie_nlb.arn
  port              = each.key
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = each.value
  }
}

# Create NLB listener for port 6443 (only for KAC)
resource "aws_lb_listener" "querypie_nlb_6443" {
  count = local.has_kac ? 1 : 0

  load_balancer_arn = aws_lb.querypie_nlb.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = var.tg_6443_arn
  }
}

# Create NLB listener for port 7447 (only for WAC)
resource "aws_lb_listener" "querypie_nlb_7447" {
  count = local.has_wac ? 1 : 0

  load_balancer_arn = aws_lb.querypie_nlb.arn
  port              = 7447
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = var.tg_7447_arn
  }
}

# Create NLB listener for port 9000
resource "aws_lb_listener" "querypie_nlb_9000" {
  load_balancer_arn = aws_lb.querypie_nlb.arn
  port              = 9000
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = var.tg_9000_arn
  }
}

# Create Route53 records if enabled
resource "aws_route53_record" "querypie_domain" {
  count = var.create_querypie_domain ? 1 : 0

  zone_id = var.aws_route53_zone_id
  name    = var.querypie_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.querypie_alb.dns_name
    zone_id                = aws_lb.querypie_alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "querypie_proxy_domain" {
  count = var.create_querypie_domain ? 1 : 0

  zone_id = var.aws_route53_zone_id
  name    = var.querypie_proxy_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.querypie_nlb.dns_name
    zone_id                = aws_lb.querypie_nlb.zone_id
    evaluate_target_health = true
  }
}

# Data source to get subnets
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}
