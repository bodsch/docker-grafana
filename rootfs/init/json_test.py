#!/usr/bin/python

import json
import os

print(json.__file__)


# if os.environ.has_key("DATASOURCES")
print os.environ['DATASOURCES']

datasources = os.environ['DATASOURCES']

data = json.dumps(datasources)

for attribute, value in data.iteritems():
  print attribute, value # example usage

if data["fa"] == "cc.ee":
  data["fb"]["new_key"] = "cc.ee was present!"

print json.dumps(data)

