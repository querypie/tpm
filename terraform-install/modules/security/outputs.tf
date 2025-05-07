output "security_group_id" {
  value       = aws_security_group.querypie_server_sg.id
  description = "ID of the security group created for the QueryPie server"
}

output "alb_security_group_id" {
  value       = var.create_lb ? aws_security_group.querypie_alb_sg[0].id : null
  description = "ID of the security group created for the ALB"
}

output "nlb_security_group_id" {
  value       = var.create_lb ? aws_security_group.querypie_nlb_sg[0].id : null
  description = "ID of the security group created for the NLB"
}
