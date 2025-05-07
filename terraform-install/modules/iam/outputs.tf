output "instance_profile_name" {
  value       = aws_iam_instance_profile.querypie.name
  description = "Name of the IAM instance profile created for the QueryPie server"
}

output "instance_profile_arn" {
  value       = aws_iam_instance_profile.querypie.arn
  description = "ARN of the IAM instance profile created for the QueryPie server"
}

output "role_name" {
  value       = aws_iam_role.this.name
  description = "Name of the IAM role created for the QueryPie server"
}

output "role_arn" {
  value       = aws_iam_role.this.arn
  description = "ARN of the IAM role created for the QueryPie server"
}