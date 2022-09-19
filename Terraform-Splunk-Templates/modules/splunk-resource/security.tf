resource "aws_security_group" "lb_sg" {
  name        = "${var.name_prefix}-alb-${var.name_component}"
  description = "Security group for splunk ALBs"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8089 
    to_port     = 8089 
    protocol    = "tcp"
    cidr_blocks = length(var._8089_cidrs) > 0? var._8089_cidrs : var.vpc_internal_cidrs
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"] 
  }

  tags = merge(
    local.common_tags,
    {
      "Name"      =  "${var.name_prefix}-alb-${var.name_component}"
    },
  )
}

resource "aws_security_group" "instance_sg" {
  name        = "${var.name_prefix}-instance-${var.name_component}"
  description = "Security group for splunk sh and forwarders instances"
  vpc_id      = var.vpc_id


  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.vpc_internal_cidrs
  }

/* need to have "all sources" for NLBs 

  ingress {
    from_port   = 8089 
    to_port     = 8089
    protocol    = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  ingress {
    from_port   = 8089
    to_port     = 8089
    protocol    = "tcp"
    cidr_blocks = var.vpc_internal_cidrs
  }
*/

  ingress {
    from_port   = 8089
    to_port     = 8089
    protocol    = "tcp"
    cidr_blocks = var.vpc_internal_cidrs
  }

  ingress {
    from_port   = -1
    to_port   = -1
    protocol    = "icmp"
    cidr_blocks = var.vpc_internal_cidrs
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"] 
  }

  tags = merge(
    local.common_tags,
    {
      "Name"      =  "${var.name_prefix}-instance-${var.name_component}"
    },
  )
}