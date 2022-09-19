import json
import logging
import boto3
import datetime 
import time 
import requests
from requests.auth import HTTPBasicAuth

secret_name = "adminUser"

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client('ec2')

def set_maintenance_mode(host,enable):
    logger.info("Attemping to set maintenance mode on host '%s' to '%s'", host, enable)
    
    # Get admin ID and password from SecretsManager
    secrets = boto3.client('secretsmanager')
    admin_info = json.loads(secrets.get_secret_value(SecretId=secret_name)['SecretString'])
    #logger.info(admin_info)
    admin_user = admin_info['admin_userid']
    admin_password = admin_info['admin_password']

    # Call Cluster Manager REST API
    url = host + '/services/cluster/manager/control/default/maintenance'
    auth = HTTPBasicAuth(admin_user, admin_password)
    response = requests.post(url, auth=auth ,data={'mode':enable}, verify=False)
    if response.status_code != 200:
        logger.error('Response from server: %i - %s', response.status_code, response.raw)
        return
        
    logger.info('Set maintenance mode to %s', enable)
    
def lambda_handler(event, context):

    logger.info(event)

    set_maintenance_mode(event['host'],event['enable'])

    return {
        'statusCode': 200,
        'body': json.dumps('Function excecution completed!!!!')
    }

