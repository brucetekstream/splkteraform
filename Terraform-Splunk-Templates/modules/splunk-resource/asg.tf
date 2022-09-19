
resource "aws_autoscaling_group" "asg" {
  //availability_zones = var.availability_zones
  name = "${var.name_prefix}-asg-${var.name_component}"
  vpc_zone_identifier = var.app_subnets
  target_group_arns   = length(var._8089_cidrs) > 0 ? [aws_alb_target_group.lb_target_8000.arn, aws_alb_target_group.lb_target_8089.*.arn[0]] : (length(var.name_component_2) > 0 ? [aws_alb_target_group.lb_target_8000.arn, aws_alb_target_group.nlb_target_8089.*.arn[0]] : [aws_alb_target_group.lb_target_8000.arn])
  
  desired_capacity   = 1
  max_size           = 1
  min_size           = 1
  wait_for_capacity_timeout = 0

  launch_template {
    id      = aws_launch_template.instance_template.id
    version = "$Latest"
  }

  tag {
    key                 = "asg:hostname"
    value               = "${local.servername}@${var.private_zone_id}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = var.hostname
    propagate_at_launch = true
  }
  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_autoscaling_lifecycle_hook" "asg_launch_hook" {
  name                   = "${var.name_prefix}-asg-${var.name_component}-launch" 
  autoscaling_group_name = aws_autoscaling_group.asg.name
  default_result          = "CONTINUE"
  heartbeat_timeout       = 60
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_LAUNCHING"
  notification_target_arn = var.ddns_topic
  role_arn                = var.ddns_role
}
/*
resource "aws_autoscaling_lifecycle_hook" "asg_terminate_hook" {
  name                   = "${var.hostname}_asg_terminate_hook"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  default_result          = "CONTINUE"
  heartbeat_timeout       = 60
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_TERMINATING"
  notification_target_arn = var.ddns_topic
  role_arn                = var.ddns_role
}
*/