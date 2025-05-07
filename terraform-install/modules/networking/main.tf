# Create target group for port 80
resource "aws_lb_target_group" "querypie_tg_80" {
  count       = var.create_lb ? 1 : 0
  name        = "${var.team}-${var.owner}-${var.project}-tg-80"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/readyz"
    port                = 80
    protocol            = "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 6
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${var.team}-${var.owner}-${var.project}-tg-80"
  }
}

# Create target group for port 9000
resource "aws_lb_target_group" "querypie_tg_9000" {
  count       = var.create_lb ? 1 : 0
  name        = "${var.team}-${var.owner}-${var.project}-tg-9000"
  port        = 9000
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/readyz"
    port                = 80
    protocol            = "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 6
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${var.team}-${var.owner}-${var.project}-tg-9000"
  }
}

# Create target group for port 6443 (only for KAC)
resource "aws_lb_target_group" "querypie_tg_6443" {
  count       = var.create_lb && local.has_kac ? 1 : 0
  name        = "${var.team}-${var.owner}-${var.project}-tg-6443"
  port        = 6443
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/readyz"
    port                = 80
    protocol            = "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 6
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${var.team}-${var.owner}-${var.project}-tg-6443"
  }
}

# Create target group for port 7447 (only for WAC)
resource "aws_lb_target_group" "querypie_tg_7447" {
  count       = var.create_lb && local.has_wac ? 1 : 0
  name        = "${var.team}-${var.owner}-${var.project}-tg-7447"
  port        = 7447
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/readyz"
    port                = 80
    protocol            = "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 6
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${var.team}-${var.owner}-${var.project}-tg-7447"
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
}

# Create target groups for agentless proxy ports (only for DAC)
resource "aws_lb_target_group" "querypie_tg_agentless_proxy_ports" {
  for_each    = var.create_lb ? { for port in local.agentless_proxy_ports : port => port } : {}
  name        = "${var.team}-${var.owner}-${var.project}-tg-${each.key}"
  port        = each.key
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/readyz"
    port                = 80
    protocol            = "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 6
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${var.team}-${var.owner}-${var.project}-tg-${each.key}"
  }
}

# Attach instance to target group for port 80
resource "aws_lb_target_group_attachment" "querypie_tg_80_attachment" {
  count            = var.create_lb ? 1 : 0
  target_group_arn = aws_lb_target_group.querypie_tg_80[count.index].arn
  target_id        = var.instance_id
  port             = 80
}

# Attach instance to target group for port 9000
resource "aws_lb_target_group_attachment" "querypie_tg_9000_attachment" {
  count            = var.create_lb ? 1 : 0
  target_group_arn = aws_lb_target_group.querypie_tg_9000[count.index].arn
  target_id        = var.instance_id
  port             = 9000
}

# Attach instance to target group for port 6443 (only for KAC)
resource "aws_lb_target_group_attachment" "querypie_tg_6443_attachment" {
  count            = var.create_lb && local.has_kac ? 1 : 0
  target_group_arn = aws_lb_target_group.querypie_tg_6443[count.index].arn
  target_id        = var.instance_id
  port             = 6443
}

# Attach instance to target group for port 7447 (only for WAC)
resource "aws_lb_target_group_attachment" "querypie_tg_7447_attachment" {
  count            = var.create_lb && local.has_wac ? 1 : 0
  target_group_arn = aws_lb_target_group.querypie_tg_7447[count.index].arn
  target_id        = var.instance_id
  port             = 7447
}

# Attach instance to target groups for agentless proxy ports (only for DAC)
resource "aws_lb_target_group_attachment" "querypie_tg_attachment" {
  for_each = var.create_lb ? { for port in local.agentless_proxy_ports : port => port } : {}

  target_group_arn = aws_lb_target_group.querypie_tg_agentless_proxy_ports[each.key].arn
  target_id        = var.instance_id
  port             = each.key
}
