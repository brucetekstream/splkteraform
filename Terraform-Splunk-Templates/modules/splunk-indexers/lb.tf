resource "aws_alb" "lb" {
  count = length(var.indexers)
  name = "${var.name_prefix}-nlb-${var.indexers[count.index].name_component}"
  subnets = [var.indexers[count.index].pub_subnet_id]
  #security_groups = [aws_security_group.lb_sg.id]
  internal           = false
  load_balancer_type = "network"
  tags = merge(
    local.common_tags,
    {
      "Name" = "${var.name_prefix}-nlb-${var.indexers[count.index].name_component}"
    },
  )
}


resource "aws_alb_listener" "listen_443" {
  count = length(var.indexers)
  load_balancer_arn = aws_alb.lb.*.id[count.index]
  port              = "443"
  protocol          = "TCP"
  #ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  #certificate_arn   = var.cert_arn

  default_action {
    target_group_arn = aws_alb_target_group.target_9995.*.id[count.index]
    type             = "forward"
  }
}


resource "aws_alb_target_group" "target_9995" {
  count = length(var.indexers)
  
  name = "${var.name_prefix}-nlb-9995-${var.indexers[count.index].name_component}"
  port       = 9995
  protocol   = "TCP"
  vpc_id     = var.vpc_id
/*
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
  }*/

  #health_check {
   # healthy_threshold   = 2
   # unhealthy_threshold = 2
  #  protocol   = "TCP"
    #timeout             = 60
    #interval            = 300
    #matcher             = "200-490"
  #}
  tags = merge(

    local.common_tags,
    {
      "Name" = "${var.name_prefix}-nlb-9995-${var.indexers[count.index].name_component}"
    },
  )
  
}
