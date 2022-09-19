output "alb_dns_name" {
  value = aws_alb.load_balancer.dns_name
}

output "intance_sg" {
  value = aws_security_group.instance_sg.id
}

output "lb_sg" {
  value = aws_security_group.lb_sg.id
}

output "launch_template" {
  value = aws_launch_template.instance_template
}