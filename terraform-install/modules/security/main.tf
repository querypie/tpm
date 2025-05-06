# Data source to get VPC details
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Local values to handle conditional security group IDs
locals {
  alb_security_group_id          = var.create_lb ? (aws_security_group.querypie_alb_sg[0].id) : null
  nlb_security_group_id          = var.create_lb ? (aws_security_group.querypie_nlb_sg[0].id) : null
  alb_security_group_ids         = [local.alb_security_group_id]
  vpc_cidr                       = [data.aws_vpc.selected.cidr_block]

  # Check if products contain specific products
  has_dac = can(regex("DAC", var.products))
  has_kac = can(regex("KAC", var.products))
  has_wac = can(regex("WAC", var.products))

  # Parse agentless_proxy_ports range (only for DAC)
  agentless_proxy_range = local.has_dac ? split("-", replace(var.agentless_proxy_ports, " ", "")) : []
  agentless_proxy_start = length(local.agentless_proxy_range) > 0 ? tonumber(local.agentless_proxy_range[0]) : 0
  agentless_proxy_end = length(local.agentless_proxy_range) > 1 ? tonumber(local.agentless_proxy_range[1]) : local.agentless_proxy_start
}

# Create ALB security group
resource "aws_security_group" "querypie_alb_sg" {
  count       = var.create_lb ? 1 : 0
  vpc_id      = var.vpc_id
  name        = "${var.team}-${var.owner}-${var.project}-alb-sg"
  description = "Security group for ALB"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.lb_allowed_cidr_blocks
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.lb_allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.team}-${var.owner}-${var.project}-alb-sg"
  }
}

# Create NLB security group
resource "aws_security_group" "querypie_nlb_sg" {
  count       = var.create_lb ? 1 : 0
  vpc_id      = var.vpc_id
  name        = "${var.team}-${var.owner}-${var.project}-nlb-sg"
  description = "Security group for NLB"

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = var.lb_allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.team}-${var.owner}-${var.project}-nlb-sg"
  }
}


resource "aws_security_group" "querypie_server_sg" {
  vpc_id      = var.vpc_id
  name        = "${var.team}-${var.owner}-${var.project}-sg"
  description = "${var.team}-${var.owner}-${var.project}-sg"

  # Ingress rules with security_groups
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = var.create_lb ? concat(var.lb_allowed_cidr_blocks, local.vpc_cidr) : var.lb_allowed_cidr_blocks
    security_groups = var.create_lb ? local.alb_security_group_ids : []
  }

  ingress {
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    cidr_blocks     = var.lb_allowed_cidr_blocks
    security_groups = var.create_lb ? [local.nlb_security_group_id] : []
  }

  # 6443 port only for KAC
  dynamic "ingress" {
    for_each = local.has_kac ? [1] : []
    content {
      from_port       = 6443
      to_port         = 6443
      protocol        = "tcp"
      cidr_blocks     = var.lb_allowed_cidr_blocks
      security_groups = var.create_lb ? [local.nlb_security_group_id] : []
    }
  }

  # 7447 port only for WAC
  dynamic "ingress" {
    for_each = local.has_wac ? [1] : []
    content {
      from_port       = 7447
      to_port         = 7447
      protocol        = "tcp"
      cidr_blocks     = var.lb_allowed_cidr_blocks
      security_groups = var.create_lb ? [local.nlb_security_group_id] : []
    }
  }


  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.lb_allowed_cidr_blocks
  }

  # Agentless proxy ports only for DAC
  dynamic "ingress" {
    for_each = local.has_dac ? [1] : []
    content {
      from_port       = local.agentless_proxy_start
      to_port         = local.agentless_proxy_end
      protocol        = "tcp"
      cidr_blocks     = var.lb_allowed_cidr_blocks
      security_groups = var.create_lb ? [local.nlb_security_group_id] : []
    }
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.team}-${var.owner}-${var.project}-sg"
  }
}

# If using an external DB, configure network access for QueryPie Server to communicate with Redis and RDS.
data "aws_security_group" "querypie_rds" {
  count = var.use_external_db ? 1 : 0

  filter {
    name   = "group-name"
    values = ["${var.team}-${var.owner}-${var.project}-rds-sg"]
  }
}

data "aws_security_group" "querypie_redis" {
  count = var.use_external_db ? 1 : 0

  filter {
    name   = "group-name"
    values = ["${var.team}-${var.owner}-${var.project}-redis-sg"]
  }
}

resource "aws_security_group_rule" "allow_ec2_access_to_querypie_redis" {
  count = var.use_external_db ? 1 : 0

  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = data.aws_security_group.querypie_redis[count.index].id
  source_security_group_id = aws_security_group.querypie_server_sg.id
}

resource "aws_security_group_rule" "allow_ec2_access_to_querypie_rds" {
  count = var.use_external_db ? 1 : 0

  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = data.aws_security_group.querypie_rds[count.index].id
  source_security_group_id = aws_security_group.querypie_server_sg.id
}
