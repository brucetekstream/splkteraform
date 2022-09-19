/*
resource "aws_security_group" "lb_sg" {
  name        = "${var.name_prefix}-nlb-indexers"
  description = "Security group for Indexers"
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

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"] 
  }

  tags = merge(
    local.common_tags,
    {
      "Name"      =  "${var.name_prefix}-nlb-indexers"
    },
  )
  lifecycle {
    create_before_destroy = true
  }
}
*/

resource "aws_security_group" "instance_sg" {
  name        = "${var.name_prefix}-instance-indexers"
  description = "Security group for Indexers"
  vpc_id      = var.vpc_id


  ingress {
    from_port   = 9995
    to_port     = 9995
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8089
    to_port     = 8089
    protocol    = "tcp"
    cidr_blocks = var.vpc_internal_cidrs
  }

  ingress {
    from_port   = 9997 
    to_port     = 9997
    protocol    = "tcp"
    cidr_blocks = var.vpc_internal_cidrs
  }

  ingress {
    from_port   = -1
    to_port   = -1
    protocol    = "icmp"
    cidr_blocks = var.vpc_internal_cidrs
  }

  ingress {
    from_port   = 9887  
    to_port     = 9887
    protocol    = "tcp"
    self = true
  }
  
/*
  ingress {
    from_port   = 8088 
    to_port     = 8088 
    protocol    = "tcp"
    security_groups = [aws_security_group.hec_lb_sg.id]
  }
*/
    ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
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
      "Name"      =  "${var.name_prefix}-instance-indexers"
    },
  )

}


/*
resource "aws_security_group" "hec_lb_sg" {
  name        = "${var.name_prefix}-alb-hec"
  description = "Security group for HEC ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443 
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
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
      "Name"      =  "${var.name_prefix}-alb-hec"
    },
  )

}
*/