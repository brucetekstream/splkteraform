/********************************
* Image builder role and policy *
********************************/

data "aws_iam_policy_document" "splunk-image-builder-profile" {
  statement {
    sid = "allowPutObject"
    actions = [
              "s3:PutObject"
    ]
    resources = ["${aws_s3_bucket.imagebuilder_logs.arn}/*"]
  }
}

resource "aws_iam_policy" "splunk-image-builder-profile" {
  name        = "${local.name_prefix}-image-builder-policy"
  description = "Default instance profile for Image Builder to build Splunk servers"
  policy = data.aws_iam_policy_document.splunk-image-builder-profile.json
}

resource "aws_iam_role" "imagebuilder-profile" {
    name    = "${local.name_prefix}-imagebuilder-profile"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["ec2.amazonaws.com"]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
    tags = merge(local.common_tags,{ } )
}

resource "aws_iam_instance_profile" "imagebuilder-instance-profile" {
    name    = "${local.name_prefix}-imagebuilder-role"
    role = aws_iam_role.imagebuilder-profile.name
    tags = merge(local.common_tags,{ } )
}

locals{
    imagebuilder_role_attachment = [
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
        "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
        "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds",
        "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder",
        aws_iam_policy.splunk-instance-profile.arn,
        aws_iam_policy.splunk-image-builder-profile.arn,
        aws_iam_policy.splunk-instance-setup-profile.arn
    ]
}

resource "aws_iam_role_policy_attachment" "imagebuilder-instance-profile" {
    count      = length(local.imagebuilder_role_attachment)
    role       = aws_iam_role.imagebuilder-profile.name
    policy_arn = local.imagebuilder_role_attachment[count.index]
}


/*******************************
* Image Builder security group *
*******************************/

resource "aws_security_group" "image_builder_sg" {
  name        = "${var.name_prefix}-image-builder"
  description = "Security group for Image Builder temp instances"
  vpc_id      = var.vpc_id

/*
  ingress {
    from_port   = 8089
    to_port     = 8089
    protocol    = "tcp"
    cidr_blocks = var.vpc_internal_cidrs
  }
*/

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"] 
  }

  tags = merge(
    local.common_tags,
    {
      "Name"      =  "${var.name_prefix}-image-builder"
    },
  )

}



/**************************************
* Base Splunk AMI (SHs, CM, DS, etc.) *
**************************************/

resource "aws_imagebuilder_component" "splunk_base" {
    name     = "splunk-base-ami-init"
    platform = "Linux"
    version  = "1.0.2" # <== Update whenever this object changes
    description = "Performs initialization of the splunk-base-ami image (e.g. create splunk user, Live Patch, Yum-Cron)"

    data = <<EOT
name: splunk-base-ami-init
description: Performs initialization of the splunk-base-ami image (e.g. create splunk user)
schemaVersion: 1.0

parameters:
  - s3_config_bucket:
      type: string
      description: The name of the S3 bucket to retrieve initialization files from.
  - image_name:
      type: string
      description: The name of the image. Used to retrieve init files from S3.
      default: splunk-base-ami

phases:
  - name: build
    steps:
      - name: CreateSplunkUser
        action: ExecuteBash
        inputs:
          commands:
            - useradd -m -r splunk
      - name: CopyInitialFilesFromS3
        action: S3Download
        inputs:
          - source: "s3://{{ s3_config_bucket }}/{{ image_name }}/home/splunk/.sprun"
            destination: /home/splunk/.sprun
      - name: SetSprunOwner
        action: SetFileOwner
        inputs:
          - path: /home/splunk/.sprun
            owner: splunk
            group: splunk
      - name: AddSprunToBashRC
        action: AppendFile
        inputs:
          - path: /home/splunk/.bashrc
            content: |
              # Call .sprun script to add aliases, etc. 
              if [ -f ~/.sprun ]; then
                   . ~/.sprun
              fi
      - name: AddSudoRightsForSplunkUser
        action: CreateFile
        inputs:
          - path: /etc/sudoers.d/splunk
            content: |
              # Allow splunk to start/stop the service
              splunk  ALL=(root) NOPASSWD: /usr/bin/systemctl * Splunkd*
              splunk  ALL=(root) NOPASSWD: /opt/splunk/bin/splunk
            overwrite: false
            permissions: 440
      - name: SplunkSystemdOverrides
        action: CreateFile
        inputs:
          - path: /etc/systemd/system/Splunkd.service.d/override.conf
            content: |
              # Set ulimits for Splunkd service
              [Service]
              LimitNOFILE=64000
              LimitNPROC=16000
              LimitFSIZE=infinity
              TasksMax=16000
              # Send $KillSignal only to main (splunkd) process, if any of the child processes is still alive after $TimeoutStopSec, SIGKILL them.
              KillMode=mixed
              # Splunk doesn't shutdown gracefully on SIGTERM
              KillSignal=SIGINT
              # Give Splunk time to shutdown - especially busy indexers can take time
              TimeoutStopSec=10min
EOT
/*
      - name: InstallLivePatch
        action: ExecuteBash
        inputs:
          commands:
            - echo "Setting up LivePatch"
            - yum -y install binutils
            - yum -y install yum-plugin-kernel-livepatch
            - yum kernel-livepatch enable -y
            - yum install -y kpatch-runtime
            - yum update -y kpatch-runtime
            - systemctl enable kpatch.service
            - amazon-linux-extras enable livepatch
            - yum update -y
      - name: InstallYumCron
        action: ExecuteBash
        inputs:
          commands:
            - echo "Installing yum-cron"
            - yum -y install yum-cron
            - systemctl enable yum-cron.service
            - systemctl start yum-cron.service
            - systemctl status yum-cron.service

EOT
*/
    tags = merge(local.common_tags,{ })
}

resource "aws_imagebuilder_image_recipe" "splunk-base-ami" {
    name         = "splunk-base-ami"
    parent_image = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:image/amazon-linux-2-x86/x.x.x"
    version      = "1.0.0" # <-- You MUST increment this whenever there are changes (add/remove component)
    lifecycle {
        create_before_destroy = true
    }

    block_device_mapping {
        device_name = "/dev/xvda"

        ebs {
            delete_on_termination = true
            volume_size           = 30
            volume_type           = "gp3"
        }
    }

    component {
        component_arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:component/update-linux/x.x.x"
    }

    component {
        component_arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:component/amazon-cloudwatch-agent-linux/x.x.x"
    }

    component {
        component_arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:component/${aws_imagebuilder_component.splunk_base.name}/x.x.x"

        parameter {
            name  = "s3_config_bucket"
            value = aws_s3_bucket.inits.id
        }
    }

    tags = merge(local.common_tags,{ })
}


resource "aws_imagebuilder_infrastructure_configuration" "splunk-base-ami" {
    name = "splunk-base-ami"
    description = "Configuration to build the base AMI to use for Splunk servers"
    instance_profile_name = aws_iam_instance_profile.imagebuilder-instance-profile.name
    instance_types = ["c5.2xlarge"]
    #key_pair = "tekstream_customer" # TODO? - build this
    security_group_ids = [aws_security_group.image_builder_sg.id]
    subnet_id = var.image_builder_subnet
    terminate_instance_on_failure = true
    logging {
        s3_logs {
            s3_bucket_name = aws_s3_bucket.imagebuilder_logs.id
        }
    }
    resource_tags = {
        S3_Config_Bucket = aws_s3_bucket.inits.id
    }

    tags = merge(local.common_tags,{ })
}

resource "aws_imagebuilder_distribution_configuration" "splunk-base-ami" {
    name = "splunk-base-ami"
    distribution {
        region = data.aws_region.current.name
        ami_distribution_configuration {
            ami_tags = merge(local.common_tags,{
                Name = "splunk-base-ami"
            })
            #name = "splunk-base-ami"
            #launch_template_configuration {
            #    launch_template_id = 
            #    default = true
            #} # TODO - tie the list of launch templates back to this somehow!?!?!?
            #launch_permission {
            #    user_ids = [""]
            #}
        }
    }
}

resource "aws_imagebuilder_image_pipeline" "splunk-base-ami" {
    name = "splunk-base-ami"
    infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.splunk-base-ami.arn
    distribution_configuration_arn = aws_imagebuilder_distribution_configuration.splunk-base-ami.arn
    image_recipe_arn = aws_imagebuilder_image_recipe.splunk-base-ami.arn
    schedule {
        schedule_expression = "cron(0 0 * * ? *)"
    }
    tags = merge(local.common_tags,{ })
}

/*
resource "aws_imagebuilder_image" "splunk-base-ami" {
    depends_on = [  
      aws_s3_object.initial_configs
    ]
    image_recipe_arn = aws_imagebuilder_image_recipe.splunk-base-ami.arn
    infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.splunk-base-ami.arn
    distribution_configuration_arn = aws_imagebuilder_distribution_configuration.splunk-base-ami.arn
}
*/

/*************
* HEC Server *
*************/

locals {
  splunk_install_tarball_name = tolist(fileset("${path.root}/init_files_for_s3/common/","splunk-*.tgz"))[0]
}

resource "aws_imagebuilder_component" "splunk_app" {
    name     = "splunk-app"
    platform = "Linux"
    version  = "1.0.1" # <== Update whenever this object changes.
    description = "Installs Splunk on the image"

    data = <<EOT
name: splunk-app
description: Installs Splunk to /opt/splunk
schemaVersion: 1.0

parameters:
  - s3_config_bucket:
      type: string
      description: The name of the S3 bucket to retrieve initialization files from.
  - image_name:
      type: string
      description: The name of the image. Used to retrieve init files from S3.
      default: splunk-forwarder-hec

phases:
  - name: build
    steps:
      - name: CreateSplunkFolder
        action: CreateFolder
        inputs:
          - path: /opt/splunk/
            owner: splunk
            group: splunk
      - name: CopyConfigFilesFromS3
        action: S3Download
        inputs:
          - source: "s3://{{ s3_config_bucket }}/{{ image_name }}/*"
            destination: /opt/splunk
      - name: CopySplunkTarballFromS3
        action: S3Download
        inputs:
          - source: "s3://{{ s3_config_bucket }}/common/${local.splunk_install_tarball_name}"
            destination: /tmp/${local.splunk_install_tarball_name}
      - name: UnTARSplunk
        action: ExecuteBash
        inputs:
          commands:
            - tar xzvf /tmp/${local.splunk_install_tarball_name} -C /opt
            - # Remove Log4J files to address CVE-2021-45105 (this is needed until Splunk updates the Log4J modules)
            - rm -rf /opt/splunk/bin/jars/vendors/spark
            - rm -ff /opt/splunk/bin/jars/vendors/libs/splunk-library-javalogging-*.jar
            - rm -rf /opt/splunk/bin/jars/thirdparty/hive*
            - rm -rf /opt/splunk/etc/apps/splunk_archiver/java-bin/jars/*

      - name: GetSplunkSecret
        action: ExecuteBash
        inputs:
          commands:
            - aws secretsmanager get-secret-value --region ${data.aws_region.current.name} --secret-id splunk.secret --query 'SecretString' --output text | grep -oP '{"splunk.secret":"\K[^"]*' > /opt/splunk/etc/auth/splunk.secret
      - name: SetFolderOwner
        action: SetFolderOwner
        inputs:
          - path: /opt/splunk
            owner: splunk
            group: splunk
      - name: CreateSplunkDOverride
        action: CreateFile
        inputs:
          - path: /etc/systemd/system/Splunkd.service.d/override.conf
            content: |
              [Service]
              LimitNOFILE=64000
              LimitNPROC=16000
              LimitFSIZE=infinity
              TasksMax=16000
              # Send $KillSignal only to main (splunkd) process, if any of the child processes is still alive after $TimeoutStopSec, SIGKILL them.
              KillMode=mixed
              # Splunk doesn't shutdown gracefully on SIGTERM
              KillSignal=SIGINT
              # Give Splunk time to shutdown - especially busy indexers can take time
              TimeoutStopSec=10min
      - name: SetSplunkAutoStart
        action: ExecuteBash
        inputs:
          commands:
            - /opt/splunk/bin/splunk enable boot-start -user splunk -systemd-managed 1 --accept-license --answer-yes
EOT

    tags = merge(local.common_tags,{ })
}

resource "aws_imagebuilder_image_recipe" "splunk-hec-ami" {
    name         = "splunk-hec-ami"
    parent_image = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:image/amazon-linux-2-x86/x.x.x"
    version      = "1.0.0" # <-- You MUST increment this whenever there are changes to the recipe (add/remove components).
    lifecycle {
        create_before_destroy = true
    }

    block_device_mapping {
        device_name = "/dev/xvda"

        ebs {
            delete_on_termination = true
            volume_size           = 30
            volume_type           = "gp3"
        }
    }

    component {
        component_arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:component/update-linux/x.x.x"
    }

    component {
        component_arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:component/amazon-cloudwatch-agent-linux/x.x.x"
    }

    component {
        component_arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:component/${aws_imagebuilder_component.splunk_base.name}/x.x.x"

        parameter {
            name  = "s3_config_bucket"
            value = aws_s3_bucket.inits.id
        }
    }

    component {
        component_arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:component/${aws_imagebuilder_component.splunk_app.name}/x.x.x"

        parameter {
            name  = "s3_config_bucket"
            value = aws_s3_bucket.inits.id
        }
    }

    tags = merge(local.common_tags,{ })
}

resource "aws_imagebuilder_infrastructure_configuration" "splunk-hec-ami" {
    name = "splunk-hec-ami"
    description = "Configuration to build the base AMI to use for Splunk HEC servers"
    instance_profile_name = aws_iam_instance_profile.imagebuilder-instance-profile.name
    instance_types = ["t3.micro"]
    #key_pair = "tekstream_customer" # TODO - build this
    security_group_ids = [aws_security_group.image_builder_sg.id]
    subnet_id = var.image_builder_subnet
    terminate_instance_on_failure = true
    logging {
        s3_logs {
            s3_bucket_name = aws_s3_bucket.imagebuilder_logs.id
        }
    }
    resource_tags = {
        S3_Config_Bucket = aws_s3_bucket.inits.id
    }

    tags = merge(local.common_tags,{ })
}

resource "aws_imagebuilder_distribution_configuration" "splunk-hec-ami" {
    name = "splunk-hec-ami"
    distribution {
        region = data.aws_region.current.name
        ami_distribution_configuration {
            ami_tags = merge(local.common_tags,{
                Name = "splunk-hec-ami"
            })
            #name = "splunk-base-ami"
            #launch_template_configuration {
            #    launch_template_id = 
            #    default = true
            #} # TODO - tie the list of launch templates back to this somehow!?!?!?
            #launch_permission {
            #    user_ids = [""]
            #}
        }
    }
}

resource "aws_imagebuilder_image_pipeline" "splunk-hec-ami" {
    name = "splunk-hec-ami"
    infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.splunk-hec-ami.arn
    distribution_configuration_arn = aws_imagebuilder_distribution_configuration.splunk-hec-ami.arn
    image_recipe_arn = aws_imagebuilder_image_recipe.splunk-hec-ami.arn
    schedule {
        schedule_expression = "cron(0 0 * * ? *)"
    }
    tags = merge(local.common_tags,{ })
}

/*
resource "aws_imagebuilder_image" "splunk-hec-ami" {
    depends_on = [  
      aws_s3_object.initial_configs
    ]
    image_recipe_arn = aws_imagebuilder_image_recipe.splunk-hec-ami.arn
    infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.splunk-hec-ami.arn
    distribution_configuration_arn = aws_imagebuilder_distribution_configuration.splunk-hec-ami.arn
}
*/