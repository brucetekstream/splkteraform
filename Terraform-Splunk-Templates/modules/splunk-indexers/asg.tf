resource "aws_autoscaling_group" "indexer" {
  count = length(var.indexers)
  //availability_zones = [var.indexers[count.index].availability_zone]
  name = "${var.name_prefix}-asg-${var.indexers[count.index].name_component}"
  
  vpc_zone_identifier = [var.indexers[count.index].priv_subnet_id]
  desired_capacity   = 1
  max_size           = 1
  min_size           = 1
  wait_for_capacity_timeout = 0
  target_group_arns   = [aws_alb_target_group.target_9995.*.arn[count.index]]

  launch_template {
    id      = aws_launch_template.instance_template.id
    version = "$Latest"
  }

  tag {
    key                 = "asg:hostname"
    value               = "${var.indexers[count.index].hostname}.${local.private_zone_name}@${var.private_zone_id}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = var.indexers[count.index].hostname
    propagate_at_launch = true
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_lifecycle_hook" "asg_launch_hook" {
  count = length(var.indexers)
  name                   = "${var.name_prefix}-asg-${var.indexers[count.index].name_component}-launch" 
  autoscaling_group_name = aws_autoscaling_group.indexer.*.name[count.index]
  default_result          = "CONTINUE"
  heartbeat_timeout       = 60
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_LAUNCHING"
  notification_target_arn = var.ddns_topic
  role_arn                = var.ddns_role
}
/*
resource "aws_autoscaling_lifecycle_hook" "asg_terminate_hook" {
  count = length(var.indexers)
  name                   = "${var.indexers[count.index].hostname}_asg_terminate_hook"
  autoscaling_group_name = aws_autoscaling_group.indexer.*.name[count.index]
  default_result          = "CONTINUE"
  heartbeat_timeout       = 60
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_TERMINATING"
  notification_target_arn = var.ddns_topic
  role_arn                = var.ddns_role
}*/