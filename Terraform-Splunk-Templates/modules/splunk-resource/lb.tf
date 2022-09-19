/* 

Use cases for an instance:
1. Single ALB listening on 443, sending to 8000 (web traffic) [example: customer SH]
2. Single ALB listening on 443 -> 8000 (web), and 8089->8089 (API) [example: security SH]
3. ALB listening on 443->8000 (web), and NLB listening on 443->8089 (API) [example: Deployment Server]
4. NLB listening on 443->9995 (S2S) [example: Indexers]
(Note: use case 4 is not covered here)

How to indicate each use case:
1. No value for _8089_cidrs.
2. Value for _8089_cidrs.
3. Values for name_component_2.
4. (Covered in splunk-indexers module.)

Here's how it uses the values:

Primary ALB (web traffic):
- name_component => alb, target group names
- public_name => DNS host name

Secondary ALB (API/mgmt traffic):
- name_component => target group name
- public_name_2 => DNS host name 
- _8089_

NLB (API/mgmt traffic):
- name_component_2 => nlb name
- public_name_2 => DNS host name

*/


/* always create ALB listening on 443 and sending to 8000 */

resource "aws_alb" "load_balancer" {
  name                             = "${var.name_prefix}-alb-${var.name_component}"
  subnets                          = var.public_subnets
  security_groups                  = [aws_security_group.lb_sg.id]
  internal                         = false
  load_balancer_type               = "application"
  enable_cross_zone_load_balancing = true

  // TEMPORARY for debugging
  access_logs { 
    bucket = var.s3_alb_logs
    prefix = var.name_component
    enabled = true
  }

  
  tags = merge(
    local.common_tags,
    {
      "Name" = "${var.name_prefix}-alb-${var.name_component}"
    },
  )
}

resource "aws_wafv2_web_acl_association" "load_balancer" {
  resource_arn = aws_alb.load_balancer.arn
  web_acl_arn  = var.waf_acl_arn
}

resource "aws_alb_listener" "load_balancer" {
  load_balancer_arn = aws_alb.load_balancer.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_alb_listener" "load_balancer_443" {
  load_balancer_arn = aws_alb.load_balancer.id
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.cert_arn

  default_action {
    target_group_arn = aws_alb_target_group.lb_target_8000.id
    type             = "forward"
  }
}

/* Not needed - splitting into 2 LBs
resource "aws_lb_listener_rule" "redirect_8089" {
  count = var.public_name_2 != "" ? 1 : 0
  listener_arn = aws_alb_listener.load_balancer_443.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.lb_target_8089.*.id[0]
  }

  condition {
    host_header {
      values = ["${var.public_name_2}.${local.public_zone_name}"]
    }
  }
}
*/

resource "aws_alb_target_group" "lb_target_8000" {
  name = "${var.name_prefix}-alb-8000-${var.name_component}"
  #name = "${var.hostname}-alb-target-8000"
  port       = 8000
  protocol   = "HTTP"
  vpc_id     = var.vpc_id
  depends_on = [aws_alb.load_balancer]
  /*
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
  }*/

  health_check {
    protocol            = "HTTP"
    path                = "/en-US/account/login"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
  tags = merge(
    local.common_tags,
    {
      "Name" = "${var.name_prefix}-alb-8000-${var.name_component}"
    },
  )
  //lifecycle {
  //  create_before_destroy = true
  //}
}


/* if _8089_cidrs is set, create a second listener, etc. */

resource "aws_alb_listener" "load_balancer_8089" {
  count             = length(var._8089_cidrs) > 0 ? 1 : 0
  load_balancer_arn = aws_alb.load_balancer.id
  port              = "8089"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.cert_arn

  default_action {
    target_group_arn = aws_alb_target_group.lb_target_8089.*.id[0]
    type             = "forward"
  }
}


resource "aws_alb_target_group" "lb_target_8089" {
  count = length(var._8089_cidrs) > 0 ? 1 : 0
  # name = "${var.hostname}-alb-target-8089"
  name       = "${var.name_prefix}-alb-8089-${var.name_component}"
  port       = 8089
  protocol   = "HTTPS"
  vpc_id     = var.vpc_id
  depends_on = [aws_alb.load_balancer]
  /*
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
  }*/

  health_check {
    protocol            = "HTTPS"
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
  tags = merge(
    local.common_tags,
    {
      "Name" = "${var.name_prefix}-alb-8089-${var.name_component}"
    },
  )
  lifecycle {
    create_before_destroy = true
  }
}


/* if name_component_2 set, create NLB for 8089 traffic */

resource "aws_alb" "mgmt_lb" {
  count   = var.name_component_2 != "" ? 1 : 0
  name    = "${var.name_prefix}-nlb-${var.public_name_2}"
  subnets = var.public_subnets
  #security_groups = [aws_security_group.lb_sg.id]
  internal                         = false
  load_balancer_type               = "network"
  enable_cross_zone_load_balancing = true

  tags = merge(
    local.common_tags,
    {
      "Name" = "${var.name_prefix}-nlb-${var.public_name_2}"
    },
  )
}


resource "aws_alb_listener" "nlb_8089" {
  count             = var.name_component_2 != "" ? 1 : 0
  load_balancer_arn = aws_alb.mgmt_lb[0].id
  port              = "443"
  protocol          = "TCP"
  #ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  #certificate_arn   = var.cert_arn

  default_action {
    target_group_arn = aws_alb_target_group.nlb_target_8089.*.id[0]
    type             = "forward"
  }
}


resource "aws_alb_target_group" "nlb_target_8089" {
  count = var.name_component_2 != "" ? 1 : 0
  # name = "${var.hostname}-alb-target-8089"
  name     = "${var.name_prefix}-nlb-${var.public_name_2}"
  port     = 8089
  protocol = "TCP"
  vpc_id   = var.vpc_id

  stickiness {
    enabled = false
    type    = "source_ip"
  }

  tags = merge(
    local.common_tags,
    {
      "Name" = "${var.name_prefix}-nlb-${var.public_name_2}"
    },
  )
}

// Below added 7/1/2021 to send an alert to Teams if a 504 error occurs on a SH

data "aws_iam_account_alias" "current" {}

resource "aws_cloudwatch_metric_alarm" "alarm_5xx" {
  alarm_name                = "${var.name_prefix}-alb-${var.name_component}-5xx-alarm"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "1"
  metric_name               = "HTTPCode_ELB_5XX_Count"
  namespace                 = "AWS/ApplicationELB"
  period                    = 60
  statistic                 = "Sum"
  threshold                 = 0.0
  alarm_description         = "One or more 5XX errors was generated on ALB ${var.name_prefix}-alb-${var.name_component}"
  alarm_actions = [ var.splunk_alarms_topic ]
  // ok_actions = [ var.splunk_alarms_topic ]
  // insufficient_data_actions = [ var.splunk_alarms_topic ]
  dimensions = {
    LoadBalancer = aws_alb.load_balancer.arn_suffix
  }
  tags = {
    AccountAlias = data.aws_iam_account_alias.current.account_alias
  }
}