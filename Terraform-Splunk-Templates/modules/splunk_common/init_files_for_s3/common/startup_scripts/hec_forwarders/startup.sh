#!/usr/bin/env bash
set -e
export AVAILABILITY_ZONE=$(curl -sLf http://112.xxx.xxx.xxx/latest/meta-data/placement/availability-zone)
export INSTANCE_ID=$(curl -sLf http://112.xxx.xxx.xxx/latest/meta-data/instance-id)
export AWS_REGION=$(curl -s 112.xxx.xxx.xxx/latest/meta-data/placement/availability-zone | sed 's/.$//')
export BASE_HOSTNAME=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCE_ID}" --region $AWS_REGION --output=text|  grep "\sName" |awk '{print $5}')
export NEW_HOSTNAME=${BASE_HOSTNAME}-${INSTANCE_ID}
export NEW_FQDN=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCE_ID}" --region $AWS_REGION --output=text|  grep "asg:hostname" |awk '{print $5}' |sed 's/@.*//')
export AWS_ACCOUNT=$(aws sts get-caller-identity |grep Account |awk '{print $2}' |sed 's/\"\,//'|sed 's/\"//')
export AWS_ALIAS=$(aws iam list-account-aliases --output text --query AccountAliases)
export S3_CONFIG_BUCKET=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCE_ID}" "Name=key,Values=S3_Config_Bucket" --region $AWS_REGION --output=text | cut -f5)

#echo "host name $INSTANCE_ID , $AWS_REGION , $NEW_HOSTNAME" > /tmp/boot.log
echo "127.0.0.1 ${NEW_HOSTNAME} ${NEW_FQDN} localhost.localdomain localhost" > /etc/hosts

hostname ${NEW_HOSTNAME}

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:/AmazonCloudWatch-Splunk

aws cloudwatch put-metric-alarm --alarm-name "${NEW_HOSTNAME}_disk_used_percent_Warning_9 5" --metric-name "disk_used_percent" --alarm-description "Warning: Disk Used is above 95% on ${NEW_HOSTNAME} in ${AWS_ALIAS}." --namespace CWAgent --statistic Average --period 60 --threshold 95 --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=${INSTANCE_ID} Name=path,Value=/ Name=device,Value=nvme0n1p1 Name=fstype,Value=xfs --evaluation-periods 5 --alarm-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --ok-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --region ${AWS_REGION} --tags Key=Hostname,Value=${NEW_HOSTNAME} Key=AccountAlias,Value=${AWS_ALIAS}
aws cloudwatch put-metric-alarm --alarm-name "${NEW_HOSTNAME}_disk_used_percent_Error_96" --metric-name "disk_used_percent" --alarm-description "Error: Disk Used is above 96% on ${NEW_HOSTNAME} in ${AWS_ALIAS}." --namespace CWAgent --statistic Average --period 60 --threshold 96 --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=${INSTANCE_ID} Name=path,Value=/ Name=device,Value=nvme0n1p1 Name=fstype,Value=xfs --evaluation-periods 5 --alarm-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --ok-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --region ${AWS_REGION} --tags Key=Hostname,Value=${NEW_HOSTNAME} Key=AccountAlias,Value=${AWS_ALIAS}
aws cloudwatch put-metric-alarm --alarm-name "${NEW_HOSTNAME}_disk_used_percent_Critical_97" --metric-name "disk_used_percent" --alarm-description "Critical: Disk Used is above 97% on ${NEW_HOSTNAME} in ${AWS_ALIAS}." --namespace CWAgent --statistic Average --period 60 --threshold 97 --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=${INSTANCE_ID} Name=path,Value=/ Name=device,Value=nvme0n1p1 Name=fstype,Value=xfs --evaluation-periods 5 --alarm-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --ok-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --region ${AWS_REGION} --tags Key=Hostname,Value=${NEW_HOSTNAME} Key=AccountAlias,Value=${AWS_ALIAS}

aws cloudwatch put-metric-alarm --alarm-name "${NEW_HOSTNAME}_CPUUtilization_Warning_90" --metric-name "CPUUtilization" --alarm-description "Warning: CPU Utilization is above 90% on ${NEW_HOSTNAME} in ${AWS_ALIAS}." --namespace AWS/EC2 --statistic Average --period 60 --threshold 90 --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=${INSTANCE_ID} --evaluation-periods 5 --alarm-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --ok-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --region ${AWS_REGION} --tags Key=Hostname,Value=${NEW_HOSTNAME} Key=AccountAlias,Value=${AWS_ALIAS}
aws cloudwatch put-metric-alarm --alarm-name "${NEW_HOSTNAME}_CPUUtilization_Error_98" --metric-name "CPUUtilization" --alarm-description "Error: CPU Utilization is above 98% on ${NEW_HOSTNAME} in ${AWS_ALIAS}." --namespace AWS/EC2 --statistic Average --period 60 --threshold 98 --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=${INSTANCE_ID} --evaluation-periods 5 --alarm-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --ok-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --region ${AWS_REGION} --tags Key=Hostname,Value=${NEW_HOSTNAME} Key=AccountAlias,Value=${AWS_ALIAS}

aws cloudwatch put-metric-alarm --alarm-name "${NEW_HOSTNAME}_swap_used_percent_Warning_75" --metric-name "swap_used_percent" --alarm-description "Warning: Swap used is above 75% on ${NEW_HOSTNAME} in ${AWS_ALIAS}." --namespace CWAgent --statistic Average --period 60 --threshold 75 --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=${INSTANCE_ID} --evaluation-periods 5 --alarm-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --ok-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --region ${AWS_REGION} --tags Key=Hostname,Value=${NEW_HOSTNAME} Key=AccountAlias,Value=${AWS_ALIAS}
aws cloudwatch put-metric-alarm --alarm-name "${NEW_HOSTNAME}_swap_used_percent_Error_85" --metric-name "swap_used_percent" --alarm-description "Error: Swap used is above 55% on ${NEW_HOSTNAME} in ${AWS_ALIAS}." --namespace CWAgent --statistic Average --period 60 --threshold 85 --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=${INSTANCE_ID} --evaluation-periods 5 --alarm-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --ok-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --region ${AWS_REGION} --tags Key=Hostname,Value=${NEW_HOSTNAME} Key=AccountAlias,Value=${AWS_ALIAS}
aws cloudwatch put-metric-alarm --alarm-name "${NEW_HOSTNAME}_swap_used_percent_Critical_95" --metric-name "swap_used_percent" --alarm-description "Critical: Swap used is above 95% on ${NEW_HOSTNAME} in ${AWS_ALIAS}." --namespace CWAgent --statistic Average --period 60 --threshold 95 --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=${INSTANCE_ID} --evaluation-periods 5 --alarm-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --ok-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --region ${AWS_REGION} --tags Key=Hostname,Value=${NEW_HOSTNAME} Key=AccountAlias,Value=${AWS_ALIAS}

# set deployment client name
cat >> /opt/splunk/etc/system/local/deploymentclient.conf << EOF
[deployment-client]
clientName = ${NEW_HOSTNAME}
EOF
    
# Start up splunk!
systemctl start Splunkd
