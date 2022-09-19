resource "aws_security_group" "lambda_sg" {
  name        = "${var.name_prefix}-lambda-SetMaintenanceMode"
  description = "Security group for the SetMaintenance Mode lambda"
  vpc_id      = var.vpc_id
/*
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
*/
  egress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    cidr_blocks     = var.vpc_internal_cidrs
  }

  tags = merge(
    local.common_tags,
    {
      "Name"      =  "${var.name_prefix}-lambda-SetMaintenanceMode"
    },
  )
}