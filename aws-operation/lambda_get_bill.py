import boto3
import datetime
import json
import os
import urllib.request
from collections import OrderedDict


def notify_to_slack(cost, target_date, stat_type):
  if not os.environ.get('WEBHOOK'):
    return
  items = list()
  for k, v in sorted(cost.items()):
    items.append('{}: {:.6f}'.format(k, float(v)))
  sysenv = os.environ.get('SYSTEM_ENV', '')
  if stat_type == 'daily':
    msg = {
      "text": "*{} {} daily cost:*\n\n{}".format(
        sysenv,
        target_date,
        '\n'.join(items)
      )
    }
  elif stat_type == 'month_cumulative':
    msg = {
      "text": "*{}: monthly comulative cost:*\n\n{}".format(
        sysenv,
        '\n'.join(items)
      )
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

def get_time_period(stat_type):
  tz_jst = datetime.timezone(datetime.timedelta(hours=9))
  if stat_type == 'daily':
    dt_end = datetime.datetime.now(tz_jst)
    dt_start = dt_end - datetime.timedelta(days=1)
  elif stat_type == 'month_cumulative':
    dt_end = datetime.datetime.now(tz_jst)
    dt_start = datetime.datetime(
      dt_end.year, dt_end.month, 1, 0, 0, 0, 0
    )
  time_period = OrderedDict()
  time_period['Start'] = dt_start.strftime('%Y-%m-%d')
  time_period['End'] = dt_end.strftime('%Y-%m-%d')
  return time_period

def lambda_handler(event, context):
  client = boto3.client('ce', 'us-east-1')
  stat_type = os.environ.get('STAT_TYPE')
  time_period = get_time_period(stat_type)
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
  notify_to_slack(p, time_period, stat_type)
  print(json.dumps(p, indent=2))

lambda_handler(None, None)
