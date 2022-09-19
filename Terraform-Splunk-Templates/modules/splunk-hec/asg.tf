resource "aws_autoscaling_group" "hec" {
  name = "${var.name_prefix}-asg-${var.name_component}"
  
  vpc_zone_identifier = var.app_subnets
  desired_capacity   = var.cnt_desired
  max_size           = var.cnt_maximum
  min_size           = var.cnt_minimum
  wait_for_capacity_timeout = 0
  target_group_arns   = [aws_alb_target_group.heclb_target_8088.arn]

  launch_template {
    id      = aws_launch_template.instance_template.id 
    version = "$Latest"
  }

  tag {
    key                 = "asg:hostname"
    value               = "${var.hostname}.${local.private_zone_name}@${var.private_zone_id}"
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

