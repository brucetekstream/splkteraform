#!/usr/bin/env bash
# set -e
export INSTANCE_ID=$(curl -sLf http://112.xxx.xxx.xxx/latest/meta-data/instance-id)
export AWS_REGION=$(curl -s 112.xxx.xxx.xxx/latest/meta-data/placement/availability-zone | sed 's/.$//')
export S3_CONFIG_BUCKET=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCE_ID}" "Name=key,Values=S3_Config_Bucket" --region $AWS_REGION --output=text | cut -f5)

# Copy startup script from S3 and run it
aws s3 cp s3://${S3_CONFIG_BUCKET}/common/startup_scripts/hec_forwarders/startup.sh /tmp 
chmod +x /tmp/startup.sh
source /tmp/startup.sh
