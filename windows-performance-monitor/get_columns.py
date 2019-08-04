#!/usr/bin/env python
# coding: utf-8

import pandas as pd
import re

IN_FILE = '1hour15sec.csv'
OUT_FILE = 'header.csv'

df = pd.read_csv(IN_FILE, low_memory=False, encoding='ShiftJIS')
columns = list(df.columns)

with open(OUT_FILE, 'w', encoding='utf-8') as fpw:
    for item in df.columns:
        item = re.sub(r'^\\+[^\\]+', '', item)
        fpw.write(item + '\n')
