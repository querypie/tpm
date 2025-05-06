# ELB module outputs.tf

output "alb_id" {
  description = "ID of the ALB"
  value       = aws_lb.querypie_alb.id
}

output "alb_arn" {
  description = "ARN of the ALB"
  value       = aws_lb.querypie_alb.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.querypie_alb.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the ALB"
  value       = aws_lb.querypie_alb.zone_id
}

output "alb_security_group_id" {
  description = "Security group ID of the ALB"
  value       = var.alb_security_group_id
}

output "nlb_id" {
  description = "ID of the NLB"
  value       = aws_lb.querypie_nlb.id
}

output "nlb_arn" {
  description = "ARN of the NLB"
  value       = aws_lb.querypie_nlb.arn
}

output "nlb_dns_name" {
  description = "DNS name of the NLB"
  value       = aws_lb.querypie_nlb.dns_name
}

output "nlb_zone_id" {
  description = "Zone ID of the NLB"
  value       = aws_lb.querypie_nlb.zone_id
}

output "nlb_security_group_id" {
  description = "Security group ID of the NLB"
  value       = var.nlb_security_group_id
}
