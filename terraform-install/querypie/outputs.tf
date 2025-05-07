output "instance_public_ip" {
  value       = module.ec2.instance_public_ip
  description = "EC2 Public IP"
}

output "aws_key_pair_filename" {
  value       = module.ec2.aws_key_pair_filename
  description = "SSH Key Filename"
}

# ELB outputs - only when create_lb is true
output "alb_dns_name" {
  value       = var.create_lb ? module.elb[0].alb_dns_name : null
  description = "ALB DNS Name"
}

output "alb_zone_id" {
  value       = var.create_lb ? module.elb[0].alb_zone_id : null
  description = "ALB Zone ID"
}

output "nlb_dns_name" {
  value       = var.create_lb ? module.elb[0].nlb_dns_name : null
  description = "NLB DNS Name"
}

output "nlb_zone_id" {
  value       = var.create_lb ? module.elb[0].nlb_zone_id : null
  description = "NLB Zone ID"
}