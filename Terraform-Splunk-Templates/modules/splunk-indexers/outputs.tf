
output "sh_intance_sg" {
  value = aws_security_group.instance_sg.id
}

/*
output "sh_lb_sg" {
  value = aws_security_group.lb_sg.id
}
*/

output "idx_public_ips" {
  value = data.aws_network_interface.eni_idx_nlb.*.association[*][0].public_ip
}