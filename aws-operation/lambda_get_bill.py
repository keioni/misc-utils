import boto3
import datetime
import json
import os
import urllib.request
from collections import OrderedDict


def notify_to_slack(cost, target_date):
  if not os.environ.get('WEBHOOK'):
    return
  items = list()
  for k, v in sorted(cost.items()):
    items.append('{}: {:.6f}'.format(k, float(v)))
  msg = {
    "text": "*{} daily cost:*\n\n{}".format(target_date, '\n'.join(items))
  }
  posting_data = ("payload=" + json.dumps(msg)).encode('utf-8')
  request = urllib.request.Request(
    os.environ.get('WEBHOOK'),
    data=posting_data,
    method='POST'
    )
  with urllib.request.urlopen(request) as response:
    response_body = response.read().decode('utf-8')
  print(response_body)
  return response_body

def normalize_result(resp):
  result = dict()
  for kv in resp['ResultsByTime'][0]['Groups']:
    service_name = kv['Keys'][0]
    cost = kv['Metrics']['BlendedCost']['Amount']
    if cost != '0':
      result[service_name] = cost
  return result

def get_time_period():
  dt_end = datetime.datetime.now()
  dt_start = dt_end - datetime.timedelta(days=1)
  time_period = OrderedDict()
  # time_period = dict()
  time_period['Start'] = dt_start.strftime('%Y-%m-%d')
  time_period['End'] = dt_end.strftime('%Y-%m-%d')
  return time_period

def lambda_handler(event, context):
  client = boto3.client('ce', 'us-east-1')
  time_period = get_time_period()
  resp = client.get_cost_and_usage(
    TimePeriod=time_period,
    Granularity='DAILY',
    Metrics=[
      'BlendedCost'
    ],
    GroupBy=[
      {
        'Type': 'DIMENSION',
        'Key': 'SERVICE'
      }
    ]
  )
  p = normalize_result(resp)
  notify_to_slack(p, time_period['Start'])
  print(json.dumps(p, indent=2))

lambda_handler(None, None)