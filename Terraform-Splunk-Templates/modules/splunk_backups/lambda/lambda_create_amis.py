import json
import logging
import boto3
import datetime 
import time 

logger = logging.getLogger()
logger.setLevel(logging.INFO)

autoscaling = boto3.client('autoscaling')
ec2 = boto3.client('ec2')

#INSTANCE_TAGS = ["splunk-indexer-01"]


    
def get_instance_id(tag):
    logger.info("Fetching Instance ID for: %s", tag)
    instances = ec2.describe_instances(
        Filters=[
            {'Name':'tag:Name', 'Values':[tag]},
            {'Name':'instance-state-name', 'Values':['running']}
        ]
        )
    instance_id =0
    for reservations in  instances['Reservations']:
        for instance in reservations ['Instances']:
            instance_id = instance ['InstanceId']
            continue
    
    return instance_id

def get_ami_snapshots(image):
    get_ami_devices = ec2.describe_images(ImageIds=[image],Owners=['self'])['Images'][0]['BlockDeviceMappings']
    logger.info("Got these devices for AMI %s : %s",image,get_ami_devices) 
    snapshotList = []
    try:
        for x in get_ami_devices:
            snapshot = x['Ebs']['SnapshotId']
            snapshotList.append(snapshot)
    except Exception as e:
        logger.error("Error getting AMI %s Snapshots %s",image,str(e)) 
    return snapshotList

def cleanup_old_amis(tag,retention,type):
    logger.info("Cleaning up Old AMIs for: %s", tag)
    amis = ec2.describe_images(
        Owners = ["self"],
        Filters=[
            {'Name':'tag:Name', 'Values':[tag]},
            {'Name':'tag:Type', 'Values':[type]},
            {'Name':'state', 'Values':['available']}
            ]
        )
    list_of_amis = []
    for x in amis['Images']:
        #logger.info(x['SnapshotId']+"   "+str(x['StartTime']))
        list_of_amis.append({'date':x['CreationDate'], 'ImageId': x['ImageId']})

        
    sorted_list = sorted(list_of_amis, key=lambda k: k['date'], reverse= False)
    #logger.info(sorted_list)
    number_of_amis=len(sorted_list)
    number_of_amis_to_delete=int(number_of_amis)-int(retention)
    
    if (number_of_amis_to_delete > 0):
        logger.info("Found %s AMIS for tag %s Retention is set to %s, %s AMIs to be deleted",number_of_amis,tag,retention,number_of_amis_to_delete)   
        amis_to_delete=sorted_list[:number_of_amis_to_delete]
        
        for a in amis_to_delete:
            image=a['ImageId']
            logger.info("Deleting AMI %s",image) 
            
            get_ami_devices = ec2.describe_images(ImageIds=[image],Owners=['self'])['Images'][0]['BlockDeviceMappings']
            snapshotList = []
            try:
                for x in get_ami_devices:
                    snapshot = x['Ebs']['SnapshotId']
                    snapshotList.append(snapshot)
            except Exception as e:
                logger.error("Error getting AMI Snapshots %s",str(e)) 
 
            amiResponse = ec2.deregister_image(DryRun=False,ImageId=image)
            logger.info(amiResponse) 
            logger.info("Deleting AMI Snapshots  %s",snapshotList) 
            for snapshot in snapshotList:
                try:
                    snap = ec2.delete_snapshot(SnapshotId=snapshot)
                except Exception as e:
                    logger.error("Error deleting AMI Snapshots %s %s",str(e),str(snap)) 
        
        return 1
    else:
        return 0

     
     

def create_ami(tag,instance_id,type):
    create_time = datetime.datetime.now()
    create_fmt = create_time.strftime('%d-%m-%Y.%H.%M')
    try:
        logger.info("Creating New AMI for: %s", tag)
        response = ec2.create_image(
            InstanceId=instance_id, 
            Name=tag+'_'+create_fmt, 
            Description="Lambda created AMI of instance " + instance_id, 
            NoReboot=True, 
            DryRun=False)

        #waiter = ec2.get_waiter('image_available')
        #waiter.wait(ImageIds=[ response['ImageId'] ])
        time.sleep(10)
        logger.info("AMI created")    

    except IndexError as e:
        logger.error("Unexpected error, instance %s check if the instance is running be in the state other then 'running'. AMI creation failed.  %s",instance_id,str(e))    
    ami_id = response['ImageId']
    
    tag_ami(tag,ami_id,type)
    
    return ami_id

def tag_ami(tag,ami_id,type):
    create_time = datetime.datetime.now()
    create_fmt = create_time.strftime('%d-%m-%Y.%H.%M')
    
    try:
        logger.info("Adding tags to AMI: %s", ami_id)
        response = ec2.create_tags(
            Resources=[ami_id], 
            Tags=[
                {'Key': 'Name', 'Value': tag},
                {'Key': 'CreatedOn', 'Value': create_fmt},
                {'Key': 'Type', 'Value': type}
                ]
            )
        ami_snapshots = get_ami_snapshots(ami_id)
        logger.info("Adding tags to Snapshots: %s", ami_snapshots)
        response = ec2.create_tags(
            Resources=ami_snapshots, 
            Tags=[
                {'Key': 'Name', 'Value': tag+"_ami"},
                {'Key': 'CreatedOn', 'Value': create_fmt},
                {'Key': 'Type', 'Value': type}
                ]
            )
    except Exception as e:
        logger.error("Unexpected error, ami_id "+ami_id+". AMI Tagging failed."+str(e)) 
    
   
        
def update_template(tag,ami_id):
    logger.info("Updating template for: %s", tag)
    template_name = tag+"_template"
    
    response = ec2.create_launch_template_version(
        LaunchTemplateName=template_name,
        SourceVersion="$Latest",
        LaunchTemplateData={
            'ImageId': ami_id
        }
    )

    logger.info(response)    
    
    
def lambda_handler(event, context):

    logger.info(event)
    #for i in INSTANCE_TAGS:
    for i in event['INSTANCE_TAGS']:
        instance_id = get_instance_id(i)
        
        if instance_id==0:
            logger.info("No instance_id Found for %s = %s", i, instance_id)
            continue
        ami_id=create_ami(tag=i,instance_id=instance_id,type=event['TYPE'])
        logger.info("AMI (%s) created for instance_id %s", ami_id, instance_id)
        
        update_template(i,ami_id)

    logger.info("STARTING AMI Cleanup")  
    for i in event['INSTANCE_TAGS']:
        cleanup=cleanup_old_amis(i,event['RETENTION'],event['TYPE'])
        if cleanup==0:
            logger.info("No old amis Found for %s ", i)
            continue

    return {
        'statusCode': 200,
        'body': json.dumps('Function excecution completed!!!!')
    }

