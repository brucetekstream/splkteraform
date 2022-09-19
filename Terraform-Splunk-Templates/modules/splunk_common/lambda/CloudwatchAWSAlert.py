#!/usr/bin/python3.8
import pymsteams
import re, pprint
import urllib3
import json
http = urllib3.PoolManager()
import boto3
import base64
from botocore.exceptions import ClientError
import logging

logger = logging.getLogger()
logger.setLevel(logging.DEBUG)

def get_secret(secret_name):
    region_name = "us-east-1"
    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )
    # In this sample we only handle the specific exceptions for the 'GetSecretValue' API.
    # See https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetSecretValue.html
    # We rethrow the exception by default.
    get_secret_value_response = "error"
    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        if e.response['Error']['Code'] == 'DecryptionFailureException':
            # Secrets Manager can't decrypt the protected secret text using the provided KMS key.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'InternalServiceErrorException':
            # An error occurred on the server side.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'InvalidParameterException':
            # You provided an invalid value for a parameter.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'InvalidRequestException':
            # You provided a parameter value that is not valid for the current state of the resource.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'ResourceNotFoundException':
            # We can't find the resource that you asked for.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
    else:
        # Decrypts secret using the associated KMS CMK.
        # Depending on whether the secret is a string or binary, one of these fields will be populated.
        if 'SecretString' in get_secret_value_response:
            secret = get_secret_value_response['SecretString']
        else:
            decoded_binary_secret = base64.b64decode(get_secret_value_response['SecretBinary'])
    return json.loads(secret)
    
def post_color(alarmName):
    colors = {
        "OK":"00FF00",
        "ALARM":"FF0000"
    }
    return colors.get(alarmName,"0000FF")
    
def list2dict(l,KeyField,ValueField):
    d = {}
    for i in l:
        d[i[KeyField]] = i[ValueField]
    return d
    
def human_readable(f,decimals=2):
    '''
    Converts a float into a human readable string, such as "3.25 MB" or "29.393 TB".
    Will use "B", "KB", "MB", "GB", or "TB".
    Determines units similar to scientific notation - if the number is >= 1024, then divide by 1024 and up the units.
    The effect is that the whole number will be between 1 and 10 (or over 10 if TB).
    The decimal portion will contain 'decimals' number of digits.
    '''
    
    s = "%." + str(decimals) + "f %s"
    units = ["B","KB","MB","GB","TB"]
    for u in units:
        if f < 1024:
            return s % (f,u)
        f /= 1024
    return s % (f*1024,units[-1])
    
def lambda_handler(event, context):
    logger.debug(str(event))

    # Get WebHook URL to post to
    url = get_secret("<customer>TeamsWebHookSecret").get("CFATeamsWebHookSecret")

    alert = json.loads(event['Records'][0]['Sns']['Message'])
    NewStateValue = alert['NewStateValue']
    trigger = alert['Trigger']
    dims = list2dict(trigger['Dimensions'],'name','value')
    MetricName = trigger['MetricName']
    logger.debug("MetricName = %s" % MetricName)
    ARN = alert['AlarmArn']
    cloudwatch = boto3.client("cloudwatch")
    alarm_tags = list2dict(cloudwatch.list_tags_for_resource(ResourceARN=ARN)['Tags'],'Key','Value')
    Hostname = alarm_tags.get('Hostname')
    Alias = alarm_tags.get('AccountAlias',alert['AWSAccountId'])
    
    msg = pymsteams.connectorcard(url)
    msg.color(post_color(NewStateValue))

    msg.title(NewStateValue + ": " + alert['AlarmName'] + (" has returned to normal" if NewStateValue=="OK" else "") + " in " + Alias)
    
    if MetricName == "CPUUtilization":
        val = re.search('\[(\d+\.\d+)', alert['NewStateReason']).group(1)
        text = "CPU utilization on %s in %s is %s%%." % (Hostname, Alias, val)
        threshold = "The alarm is in the ALARM state when %s is %s %d for %d seconds." % (trigger['MetricName'], trigger['ComparisonOperator'], trigger['Threshold'], trigger['EvaluationPeriods'] * trigger['Period'])
    elif MetricName == "disk_used_percent":
        val = re.search('\[(\d+\.\d{0,2})', alert['NewStateReason']).group(1)
        text = "Disk usage on %s on %s in %s is %s%%." % (dims['path'], Hostname, Alias, val)
        threshold = "The alarm is in the ALARM state when %s is %s %s for %d seconds." % (trigger['MetricName'], trigger['ComparisonOperator'], human_readable(trigger['Threshold']), trigger['EvaluationPeriods'] * trigger['Period'])
    elif MetricName == "swap_used_percent":
        val = re.search('\[(\d+\.\d{0,2})', alert['NewStateReason']).group(1)
        text = "Swap usage on %s in %s is %s%%." % (Hostname, Alias, val)
        threshold = "The alarm is in the ALARM state when %s is %s %s for %d seconds." % (trigger['MetricName'], trigger['ComparisonOperator'], human_readable(trigger['Threshold']), trigger['EvaluationPeriods'] * trigger['Period'])
    elif MetricName == "disk_free":
        val = float(re.search('\[([\d\.E]+)', alert['NewStateReason']).group(1))
        free = human_readable(val,2)
        text = "Free disk space on %s on %s in %s is %s." % (dims['path'], Hostname, Alias, free) # TODO - is it reported in MB?
        threshold = "The alarm is in the ALARM state when %s is %s %s for %d seconds." % (trigger['MetricName'], trigger['ComparisonOperator'], human_readable(trigger['Threshold']), trigger['EvaluationPeriods'] * trigger['Period'])
    else:
        text = "%s in %s" % (alert['AlarmDescription'], Alias)
        threshold = "The alarm is in the ALARM state when %s is %s %d for %d seconds." % (trigger['MetricName'], trigger['ComparisonOperator'], trigger['Threshold'], trigger['EvaluationPeriods'] * trigger['Period'])
    
    msg.text(text)
    msg.summary(text)

    # Alarm Details
    s = pymsteams.cardsection()
    #s.title("**Alarm Details**")
    s.addFact("Name", alert['AlarmName'])
    s.addFact("Description", alert['AlarmDescription'])
    s.addFact("State Change", alert['OldStateValue'] + " -> " + NewStateValue)
    s.addFact("Reason for State Change", alert['NewStateReason'])
    s.addFact("Timestamp", alert['StateChangeTime'])
    s.addFact("AWS Account", alert['AWSAccountId'] + " (" + Alias + ")")
    s.addFact("Threshold", threshold)
    msg.addSection(s)
    
    msg.send()