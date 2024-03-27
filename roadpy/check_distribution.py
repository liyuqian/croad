import json
import sys

import plotly.express as px

with open(sys.argv[1]) as f:
  data = json.load(f)
  f.close()

xRatios = []

for key in data:
  value = data[key]
  if value:
    xRatios.append(value['xRatio'])

px.histogram(xRatios).show()
