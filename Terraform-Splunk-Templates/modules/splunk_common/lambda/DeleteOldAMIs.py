import json
import logging
import boto3
import datetime 
import time 

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client('ec2')

def cleanup_old_amis(tag,retention):
    logger.info("Cleaning up older AMIs for '%s', keeping the latest %i images.", tag, retention)
    retention = int(retention)
    # Check to make sure we are keeping at least 1 copy (the latest)
    if retention < 1:
        logger.warn("# of instances to keep was less than 1. Resetting to keep 1 image.")
        retention = 1

    amis = ec2.describe_images(
        Owners = ["self"],
        Filters=[
            {'Name':'tag:Name', 'Values':[tag]},
            {'Name':'state', 'Values':['available']}
            ]
        )
    logger.info("Found %i images.",len(amis['Images']))
    list_of_amis = []
    for x in amis['Images']:
        #logger.info(x['SnapshotId']+"   "+str(x['StartTime']))
        list_of_amis.append({'date':x['CreationDate'], 'ImageId': x['ImageId']})

        
    sorted_list = sorted(list_of_amis, key=lambda k: k['date'], reverse= False)
    logger.info(sorted_list)
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

         
def lambda_handler(event, context):

    logger.info(event)

    for i in event['ami_names']:
        cleanup=cleanup_old_amis(i,event['num_to_keep'])
        if cleanup==0:
            logger.info("No old amis Found for %s ", i)
            continue

    return {
        'statusCode': 200,
        'body': json.dumps('Function excecution completed!!!!')
    }

