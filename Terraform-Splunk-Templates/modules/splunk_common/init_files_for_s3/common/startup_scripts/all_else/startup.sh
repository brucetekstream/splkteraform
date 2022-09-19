#!/usr/bin/env bash
# set -e
export AVAILABILITY_ZONE=$(curl -sLf http://112.xxx.xxx.xxx/latest/meta-data/placement/availability-zone)
export INSTANCE_ID=$(curl -sLf http://112.xxx.xxx.xxx/latest/meta-data/instance-id)
export AWS_REGION=$(curl -s 112.xxx.xxx.xxx/latest/meta-data/placement/availability-zone | sed 's/.$//')
export NEW_HOSTNAME=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCE_ID}" --region $AWS_REGION --output=text|  grep "\sName" |awk '{print $5}')
export NEW_FQDN=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCE_ID}" --region $AWS_REGION --output=text|  grep "asg:hostname" |awk '{print $5}' |sed 's/@.*//')
export AWS_ACCOUNT=$(aws sts get-caller-identity |grep Account |awk '{print $2}' |sed 's/\"\,//'|sed 's/\"//')
export AWS_ALIAS=$(aws iam list-account-aliases --output text --query AccountAliases)
export S3_CONFIG_BUCKET=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCE_ID}" "Name=key,Values=S3_Config_Bucket" --region $AWS_REGION --output=text | cut -f5)

#echo "host name $INSTANCE_ID , $AWS_REGION , $NEW_HOSTNAME" > /tmp/boot.log
echo "127.0.0.1 ${NEW_HOSTNAME} ${NEW_FQDN} localhost.localdomain localhost" > /etc/hosts

hostname ${NEW_HOSTNAME}

cat >> /etc/cloud/cloud.cfg << EOF
# Preserve hostname across reboots
preserve_hostname: true
EOF
hostnamectl set-hostname ${NEW_HOSTNAME}

# Install latest version of AWS CLI v2
yum -y remove awscli
cd ~
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf ~/aws

# Find and attach, or create a new volume for /opt/splunk
# First, look for an existing volume with a Name of ${NEW_HOSTNAME}:app (e.g. "splunk-utility:app").
# If we find one, forcibly detach it from any instance it is currently attached to, then attach it to me.
# If we don't find one, then create a new volume and install Splunk on it. (This should only be the first time.)
current_volume=$(aws ec2 describe-volumes --region ${AWS_REGION} --filters Name=tag:Name,Values=${NEW_HOSTNAME}:app --query "Volumes[*].VolumeId" --output text)

# Create mount point
mkdir /opt/splunk

if [ -n "$current_volume" ]; then
    # First, try to connect existing volume
    echo "Found existing app volume ${current_volume}. Attempting to attach it."
    # May need to wait to let the volume get detached from an old instance (e.g. if it crashes). Try 10 times with 10 seconds in-between each.
    retries=5
    for ((i=0; i<retries; i++)); do
        aws ec2 attach-volume --region ${AWS_REGION} --device /dev/xvdb --instance-id ${INSTANCE_ID} --volume-id ${current_volume}
        [[ $? -eq 0 ]] && break

        echo "Can't attach to volume yet. Wait 10 seconds and retry."
        sleep 10
    done
    if [ retries -eq i ]; then
        echo 'AttachVolume Failed!'
    else
        # Sleep for a bit to let the attach finish
        sleep 10
        # Mount it! (Don't need to set it up in /etc/fstab, because if this instance ever reboots, ASG will kick in and build a new instance!)
        mount /dev/nvme1n1 /opt/splunk
        echo "Mounted volume ${current_volume} as /dev/nvme1n1 on /opt/splunk."
    fi
fi

if [ ! -b "/dev/nvme1n1" ]; then
    # Second, look for a snapshot to use to restore from first...
    echo "Looking for existing snapshot with Name of ${NEW_HOSTNAME}:app..."
    snapshot_id=$(aws ec2 --region ${AWS_REGION} describe-snapshots --filters Name=tag:Name,Values=${NEW_HOSTNAME}:app --query "sort_by(Snapshots, &StartTime)[-1].{SnapshotId:SnapshotId}" --output text)
    if [ "$snapshot_id" != "None" ]; then
        echo "Found snapshot ${snapshot_id}. Attempting to create new volume..."
        # TODO - replace volume type and size in next line with TF variables.
        new_volume_json=$(aws ec2 create-volume --region ${AWS_REGION} --availability-zone ${AVAILABILITY_ZONE} --snapshot-id ${snapshot_id} --volume-type gp3 --size 100 --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=\"${NEW_HOSTNAME}:app\"}]")
        new_volume_id=$(echo $new_volume_json | grep -oP '"VolumeId": "\K[^"]*')
        echo New Volume ID: ${new_volume_id}
        # Wait to let the volume get created. Try 10 times with 10 seconds in-between each.
        retries=5
        for ((i=0; i<retries; i++)); do
            aws ec2 attach-volume --region ${AWS_REGION} --device /dev/xvdb --instance-id ${INSTANCE_ID} --volume-id ${new_volume_id}
            [[ $? -eq 0 ]] && break

            echo "Can't attach to volume yet. Wait 10 seconds and retry."
            sleep 10
        done
        if [ retries -eq i ]; then
            echo 'AttachVolume Failed!'
        else
            # Sleep to allow it to attach
            sleep 10
            echo "Created and attached volume ${new_volume_id}."
            # Mount it! (Don't need to set it up in /etc/fstab, because if this instance ever reboots, ASG will kick in and build a new instance!)
            mount /dev/nvme1n1 /opt/splunk
            echo "Mounted volume /dev/nvme1n1 to /opt/splunk."
            success=true
        fi
    fi
fi

if [ ! -b "/dev/nvme1n1" ]; then
    # Finally, create a new volume and install Splunk on it.
    echo "No existing volume or snapshot found. Creating new one."
    new_volume_json=$(aws ec2 create-volume --region ${AWS_REGION} --availability-zone ${AVAILABILITY_ZONE} --volume-type gp3 --size 100 --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=\"${NEW_HOSTNAME}:app\"},{Key=DailyBackups,Value="true"},{Key=HourlyBackups,Value="true"}]")
    echo ${new_volume_json}
    new_volume_id=$(echo $new_volume_json | grep -oP '"VolumeId": "\K[^"]*')
    echo New Volume ID: ${new_volume_id}
    # Wait to let the volume get created. Try 10 times with 10 seconds in-between each.
    retries=5
    for ((i=0; i<retries; i++)); do
        aws ec2 attach-volume --region ${AWS_REGION} --device /dev/xvdb --instance-id ${INSTANCE_ID} --volume-id ${new_volume_id}
        [[ $? -eq 0 ]] && break

        echo "Can't attach to volume yet. Wait 10 seconds and retry."
        sleep 10
    done
    (( retries == i )) && { echo 'AttachVolume Failed!'; exit 1; }

    # Sleep to allow the attach to complete
    sleep 10

    # See if volume is attached
    if [ -b "/dev/nvme1n1" ]; then
        echo "Created and attached volume ${new_volume_id}."
        # Make filesystem
        mkfs -t xfs /dev/nvme1n1
        # Create mount point
        mkdir /opt/splunk
        # Mount it! (Don't need to set it up in /etc/fstab, because if this instance ever reboots, ASG will kick in and build a new instance!)
        mount /dev/nvme1n1 /opt/splunk
        echo "Mounted volume /dev/nvme1n1 to /opt/splunk."

        # Copy Splunk from S3 - THERE SHOULD BE ONLY ONE!
        aws s3 cp s3://${S3_CONFIG_BUCKET}/common/ /tmp --recursive --include "splunk-*.tgz"
        # Untar it
        tar xzvf /tmp/splunk-*.tgz -C /opt

        # Remove Log4J files to address CVE-2021-45105 (this is needed until Splunk updates the Log4J modules)
        rm -rf /opt/splunk/bin/jars/vendors/spark
        rm -ff /opt/splunk/bin/jars/vendors/libs/splunk-library-javalogging-*.jar
        rm -rf /opt/splunk/bin/jars/thirdparty/hive*
        rm -rf /opt/splunk/etc/apps/splunk_archiver/java-bin/jars/*

        # Copy down initial config scripts from S3
        aws s3 sync s3://${S3_CONFIG_BUCKET}/${NEW_HOSTNAME} /opt/splunk

        # Copy common splunk.secret from Secrets Manager
        aws secretsmanager get-secret-value --region ${AWS_REGION} --secret-id splunk.secret --query 'SecretString' --output text | grep -oP '{"splunk.secret":"\K[^"]*' > /opt/splunk/etc/auth/splunk.secret

        # Create Splunk admin user - user-seed.conf should take care of this

        # set deployment client name
        cat >> /opt/splunk/etc/system/local/deploymentclient.conf << EOF
[deployment-client]
clientName = ${NEW_HOSTNAME}
EOF

    else
        echo "Could not attach volume!!!"
    fi
fi

# Final chown to ensure Splunk owns everything
chown -R splunk:splunk /opt/splunk

# Set Splunk to start at boot
/opt/splunk/bin/splunk enable boot-start -user splunk -systemd-managed 1 --accept-license --answer-yes

# Start up splunk!
systemctl start Splunkd

# Set up /etc/fstab so that volumes will auto-mount if indexer is restarted. Really only needed for Dev.
echo "UUID=$(lsblk /dev/nvme1n1 -n -o UUID)   /opt/splunk    xfs    defaults,nofail    0    2" >> /etc/fstab

# Change roles for this instance so that it doesn't have access to create/attach volumes, etc. moving forward

# Get existing profile ARN and association ID
TEMP=$(aws ec2 describe-iam-instance-profile-associations --region ${AWS_REGION} --filters Name=instance-id,Values=${INSTANCE_ID} --query "IamInstanceProfileAssociations[*].[AssociationId,IamInstanceProfile.Arn]" --output text)
# split it into parts
TEMP_ARY=($TEMP)
ASSOCIATION_ID=${TEMP_ARY[0]}
# STrip out "-setup" from ARN along the way
PROFILE_ARN=${TEMP_ARY[1]/-setup/}

# Replace profile for existing assocation
aws ec2 replace-iam-instance-profile-association --region ${AWS_REGION} --iam-instance-profile Arn=${PROFILE_ARN} --association-id ${ASSOCIATION_ID}
echo "IAM role updated to ${PROFILE_ARN}."

# Set up CloudWatch alerts
mkdir /usr/share/collectd
touch /usr/share/collectd/types.db

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:/AmazonCloudWatch-Splunk

aws cloudwatch put-metric-alarm --alarm-name "${NEW_HOSTNAME}_disk_used_percent_Warning_95" --metric-name "disk_used_percent" --alarm-description "Warning: Disk Used is above 95% on ${NEW_HOSTNAME} in ${AWS_ALIAS}." --namespace CWAgent --statistic Average --period 60 --threshold 95 --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=${INSTANCE_ID} Name=path,Value=/ Name=device,Value=nvme0n1p1 Name=fstype,Value=xfs --evaluation-periods 5 --alarm-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --ok-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --region ${AWS_REGION} --tags Key=Hostname,Value=${NEW_HOSTNAME} Key=AccountAlias,Value=${AWS_ALIAS}
aws cloudwatch put-metric-alarm --alarm-name "${NEW_HOSTNAME}_disk_used_percent_Error_96" --metric-name "disk_used_percent" --alarm-description "Error: Disk Used is above 96% on ${NEW_HOSTNAME} in ${AWS_ALIAS}." --namespace CWAgent --statistic Average --period 60 --threshold 96 --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=${INSTANCE_ID} Name=path,Value=/ Name=device,Value=nvme0n1p1 Name=fstype,Value=xfs --evaluation-periods 5 --alarm-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --ok-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --region ${AWS_REGION} --tags Key=Hostname,Value=${NEW_HOSTNAME} Key=AccountAlias,Value=${AWS_ALIAS}
aws cloudwatch put-metric-alarm --alarm-name "${NEW_HOSTNAME}_disk_used_percent_Critical_97" --metric-name "disk_used_percent" --alarm-description "Critical: Disk Used is above 97% on ${NEW_HOSTNAME} in ${AWS_ALIAS}." --namespace CWAgent --statistic Average --period 60 --threshold 97 --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=${INSTANCE_ID} Name=path,Value=/ Name=device,Value=nvme0n1p1 Name=fstype,Value=xfs --evaluation-periods 5 --alarm-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --ok-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --region ${AWS_REGION} --tags Key=Hostname,Value=${NEW_HOSTNAME} Key=AccountAlias,Value=${AWS_ALIAS}

aws cloudwatch put-metric-alarm --alarm-name "${NEW_HOSTNAME}_CPUUtilization_Warning_90" --metric-name "CPUUtilization" --alarm-description "Warning: CPU Utilization is above 90% on ${NEW_HOSTNAME} in ${AWS_ALIAS}." --namespace AWS/EC2 --statistic Average --period 60 --threshold 90 --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=${INSTANCE_ID} --evaluation-periods 5 --alarm-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --ok-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --region ${AWS_REGION} --tags Key=Hostname,Value=${NEW_HOSTNAME} Key=AccountAlias,Value=${AWS_ALIAS}
aws cloudwatch put-metric-alarm --alarm-name "${NEW_HOSTNAME}_CPUUtilization_Error_98" --metric-name "CPUUtilization" --alarm-description "Error: CPU Utilization is above 98% on ${NEW_HOSTNAME} in ${AWS_ALIAS}." --namespace AWS/EC2 --statistic Average --period 60 --threshold 98 --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=${INSTANCE_ID} --evaluation-periods 5 --alarm-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --ok-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --region ${AWS_REGION} --tags Key=Hostname,Value=${NEW_HOSTNAME} Key=AccountAlias,Value=${AWS_ALIAS}

aws cloudwatch put-metric-alarm --alarm-name "${NEW_HOSTNAME}_swap_used_percent_Warning_75" --metric-name "swap_used_percent" --alarm-description "Warning: Swap used is above 75% on ${NEW_HOSTNAME} in ${AWS_ALIAS}." --namespace CWAgent --statistic Average --period 60 --threshold 75 --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=${INSTANCE_ID} --evaluation-periods 5 --alarm-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --ok-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --region ${AWS_REGION} --tags Key=Hostname,Value=${NEW_HOSTNAME} Key=AccountAlias,Value=${AWS_ALIAS}
aws cloudwatch put-metric-alarm --alarm-name "${NEW_HOSTNAME}_swap_used_percent_Error_85" --metric-name "swap_used_percent" --alarm-description "Error: Swap used is above 55% on ${NEW_HOSTNAME} in ${AWS_ALIAS}." --namespace CWAgent --statistic Average --period 60 --threshold 85 --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=${INSTANCE_ID} --evaluation-periods 5 --alarm-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --ok-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --region ${AWS_REGION} --tags Key=Hostname,Value=${NEW_HOSTNAME} Key=AccountAlias,Value=${AWS_ALIAS}
aws cloudwatch put-metric-alarm --alarm-name "${NEW_HOSTNAME}_swap_used_percent_Critical_95" --metric-name "swap_used_percent" --alarm-description "Critical: Swap used is above 95% on ${NEW_HOSTNAME} in ${AWS_ALIAS}." --namespace CWAgent --statistic Average --period 60 --threshold 95 --comparison-operator GreaterThanThreshold --dimensions Name=InstanceId,Value=${INSTANCE_ID} --evaluation-periods 5 --alarm-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --ok-actions arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT}:splunk-alarms --region ${AWS_REGION} --tags Key=Hostname,Value=${NEW_HOSTNAME} Key=AccountAlias,Value=${AWS_ALIAS}

