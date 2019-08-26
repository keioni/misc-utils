import boto3
import json
from datetime import datetime


def is_true(bexp):
  if type(bexp) == str:
    return bexp.lower() in ('true', 'yes', 'on', 'enable')
  return bool(bexp)

def json_dt(object):
  if isinstance(object, datetime):
    return object.isoformat()

def get_tag_value(tags, key_name, default = ''):
  for tag in tags:
    if tag['Key'].lower() == key_name.lower():
      return tag['Value']
  return default

def pickup_targets(resp, target_user, target_time):
  picked = list()
  for reservation in resp['Reservations']:
      for instance in reservation['Instances']:
        tags = instance['Tags']
        tag_user = get_tag_value(tags, 'User')
        tag_time = get_tag_value(tags, 'AutoShutdownTime')
        if target_user == tag_user and target_time == tag_time:
          picked.append(instance)
  return picked

def do_stop(client, instance, dry_run = ''):
  instance_id = instance['InstanceId']
  instance_name = get_tag_value(instance['Tags'], 'Name')
  dry_run = is_true(dry_run)
  try:
    result = client.stop_instances(
      InstanceIds=[instance_id],
      DryRun=dry_run)
    result = json.dumps(result, default=json_dt)
    print(F'Stopping {instance_name} -> {result}')
    return True
  except Exception as e:
    if e.response['Error']['Code'] == 'DryRunOperation': # pylint: disable=no-member
      print(F'Skipped dry run: {instance_name}')
      return True
    print(F'Failed stopping {instance_name} -> {e.args}')
    return False

def lambda_handler(event, context):
  stopping_instances = list()
  tag_user = event['user']
  tag_time = event['time']
  print(F'Stop all instances tagged by "{tag_user}"')
  client = boto3.client('ec2', 'ap-northeast-1')
  resp = client.describe_instances()
  for instance in pickup_targets(resp, tag_user, tag_time):
    if do_stop(client, instance, event.get('dry_run')):
      stopping_instances.append(get_tag_value(instance['Tags'], 'Name'))
  return 'Stopping: ' + str(stopping_instances)
