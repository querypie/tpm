# Outputs for the networking module
output "tg_80_arn" {
  description = "ARN of the target group for port 80"
  value       = var.create_lb ? aws_lb_target_group.querypie_tg_80[0].arn : ""
}

output "tg_9000_arn" {
  description = "ARN of the target group for port 9000"
  value       = var.create_lb ? aws_lb_target_group.querypie_tg_9000[0].arn : ""
}

output "tg_6443_arn" {
  description = "ARN of the target group for port 6443"
  value       = var.create_lb && local.has_kac ? aws_lb_target_group.querypie_tg_6443[0].arn : ""
}

output "tg_7447_arn" {
  description = "ARN of the target group for port 7447"
  value       = var.create_lb && local.has_wac ? aws_lb_target_group.querypie_tg_7447[0].arn : ""
}

output "tg_agentless_proxy_ports_arns" {
  description = "ARNs of the target groups for agentless proxy ports"
  value       = var.create_lb ? { for port in local.agentless_proxy_ports : port => aws_lb_target_group.querypie_tg_agentless_proxy_ports[port].arn } : {}
}