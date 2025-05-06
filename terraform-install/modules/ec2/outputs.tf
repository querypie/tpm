output "instance_id" {
  value       = aws_instance.querypie_ec2.id
  description = "EC2 Instance ID"
}

output "instance_private_ip" {
  value       = aws_instance.querypie_ec2.private_ip
  description = "EC2 Private IP"
}

output "instance_public_ip" {
  value       = aws_instance.querypie_ec2.public_ip
  description = "EC2 Public IP"
}

output "aws_key_pair_filename" {
  value       = var.create_new_key_pair ? local_file.ssh_key[0].filename : "${var.team}-${var.owner}-${var.project}-key.pem"
  description = "SSH Key Filename"
}