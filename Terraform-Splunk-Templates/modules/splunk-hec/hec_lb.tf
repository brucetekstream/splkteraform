resource "aws_alb" "hec_lb" {
  name = "${var.name_prefix}-alb-hec"
  subnets = var.public_subnets
  security_groups = [aws_security_group.hec_lb_sg.id]
  internal           = false
  load_balancer_type = "application"
  enable_cross_zone_load_balancing = true
  tags = merge(
    local.common_tags,
    {
      "Name" = "${var.name_prefix}-alb-hec"
    },
  )
}

resource "aws_alb_listener" "heclb_443" {
  load_balancer_arn = aws_alb.hec_lb.id
  port              = "443"
  protocol          = "HTTPS"
  #ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.cert_arn

  default_action {
    target_group_arn = aws_alb_target_group.heclb_target_8088.id
    type             = "forward"
  }
}


resource "aws_alb_target_group" "heclb_target_8088" {
  name = "${var.name_prefix}-alb-8088-hec" 
  port       = 8088
  protocol   = "HTTPS"
  vpc_id     = var.vpc_id
/*
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
  }*/
  deregistration_delay = 60
  load_balancing_algorithm_type = "least_outstanding_requests"

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    path = "/services/collector/health"
    timeout             = 5
    interval            = 15
    matcher             = "200"
    protocol = "HTTPS"
  }
  tags = merge(

    local.common_tags,
    {
      "Name" = "${var.name_prefix}-alb-8088-hec" 
    },
  )
  
}

// Below added 7/14/2021 to send an alert to Teams if a 504 error occurs on a SH

data "aws_iam_account_alias" "current" {}

resource "aws_cloudwatch_metric_alarm" "alarm_5xx" {
  alarm_name                = "${var.name_prefix}-alb-hec-5xx-alarm"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "1"
  metric_name               = "HTTPCode_ELB_5XX_Count"
  namespace                 = "AWS/ApplicationELB"
  period                    = 60
  statistic                 = "Sum"
  threshold                 = 0.0
  alarm_description         = "One or more 5XX errors was generated on ALB ${var.name_prefix}-alb-hec"
  alarm_actions = [ var.splunk_alarms_topic ]
  // ok_actions = [ var.splunk_alarms_topic ]
  // insufficient_data_actions = [ var.splunk_alarms_topic ]
  dimensions = {
    LoadBalancer = aws_alb.hec_lb.arn_suffix
  }
  tags = {
    AccountAlias = data.aws_iam_account_alias.current.account_alias
  }
}