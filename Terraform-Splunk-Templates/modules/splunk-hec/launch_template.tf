data "aws_ami" "ami_source" {
  most_recent = true
  owners = ["self"]
  filter {
    name   = "tag:Name"
    values = ["splunk-base-ami"]
  }
}

resource "aws_launch_template" "instance_template" {
  name   = "${var.hostname}_template"
  image_id      = data.aws_ami.ami_source.id
  instance_type = var.instance_type
  key_name = var.key_name
  update_default_version = true
 
  block_device_mappings {
    device_name = "/dev/xvda" 
    ebs {
      volume_size = var.volume_size
      volume_type = "gp3"
      delete_on_termination = true
    }
  }
  
 // ebs_optimized = true

  iam_instance_profile {
    name = var.instance_profile
  }
  monitoring {
    enabled = true
  }

  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  
  tag_specifications {
    resource_type = "volume"

    tags = merge(
      local.common_tags,
      { 
        "Name"      =  "${var.hostname}:root"
      }
    )

  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.common_tags,
      { 
        "SessionsManager"      =  "Devops",
        "S3_Config_Bucket"    = var.s3_config_bucket
      }
    )

  }
    user_data = filebase64("${path.module}/scripts/bootstrap.sh")

}