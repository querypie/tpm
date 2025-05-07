locals {
  # Check if products contain specific products
  has_dac = can(regex("DAC", var.products))
  has_sac = can(regex("SAC", var.products))
  has_kac = can(regex("KAC", var.products))
  has_wac = can(regex("WAC", var.products))

  # Systems Manager policy for EC2 instance management (always included)
  ssm_policies = {
    "ssm" = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  # AWS managed policies (only SSM now, as DAC and SAC use custom policies)
  aws_managed_policies = local.ssm_policies

  # Common name prefix for resources
  name_prefix = "${var.team}-${var.owner}-${var.project}"
}

resource "aws_iam_instance_profile" "querypie" {
  name = "${local.name_prefix}-instance-role"
  role = aws_iam_role.this.name
}

resource "aws_iam_role" "this" {
  name               = "${local.name_prefix}-instance-role"
  assume_role_policy = data.aws_iam_policy_document.this.json
}

# Attach AWS managed policies to the IAM role
resource "aws_iam_role_policy_attachment" "managed_policies" {
  for_each   = local.aws_managed_policies
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

# Create custom policy for DAC (Data Access Control) - only if DAC is selected
resource "aws_iam_policy" "dac_policy" {
  count       = local.has_dac ? 1 : 0
  name        = "${local.name_prefix}-dac-policy"
  description = "Policy to allow access to data services (DynamoDB, ElastiCache, Redshift, RDS, EC2)"
  policy      = data.aws_iam_policy_document.dac_policy.json
}

# Attach custom DAC policy to the IAM role - only if DAC is selected
resource "aws_iam_role_policy_attachment" "dac_policy_attachment" {
  count      = local.has_dac ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.dac_policy[0].arn
}

# Create custom policy for KAC (Kubernetes Access Control) - only if KAC is selected
resource "aws_iam_policy" "kac_policy" {
  count       = local.has_kac ? 1 : 0
  name        = "${local.name_prefix}-kac-policy"
  description = "Policy to allow access to EKS clusters and associated resources"
  policy      = data.aws_iam_policy_document.kac_policy.json
}

# Attach custom KAC policy to the IAM role - only if KAC is selected
resource "aws_iam_role_policy_attachment" "kac_policy_attachment" {
  count      = local.has_kac ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.kac_policy[0].arn
}

# Create custom policy for SAC (Server Access Control) - only if SAC is selected
resource "aws_iam_policy" "sac_policy" {
  count       = local.has_sac ? 1 : 0
  name        = "${local.name_prefix}-sac-policy"
  description = "Policy to allow access to EC2 resources"
  policy      = data.aws_iam_policy_document.sac_policy.json
}

# Attach custom SAC policy to the IAM role - only if SAC is selected
resource "aws_iam_role_policy_attachment" "sac_policy_attachment" {
  count      = local.has_sac ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.sac_policy[0].arn
}

data "aws_iam_policy_document" "this" {
  statement {
    sid = "1"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "dac_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:*",
      "elasticache:*",
      "redshift:Describe*",
      "rds:Describe*",
      "rds:ListTagsForResource",
      "athena:*",
      "s3:*",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "sac_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "ec2:Get*",
      "ec2:List*"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "kac_policy" {
  statement {
    effect = "Allow"
    actions = [
      "eks:ListClusters",
      "eks:DescribeCluster",
      "eks:ListAccessEntries",
      "eks:DescribeAccessEntry",
      "eks:CreateAccessEntry",
      "eks:ListAssociatedAccessPolicies",
      "eks:AssociateAccessPolicy"
    ]
    resources = ["*"]
  }
}
