#!/usr/bin/env python3

import sys
import csv

with open(sys.argv[1]) as f:
    txt_pdf = {}
    for row in csv.reader(f, delimiter='\t', quoting=csv.QUOTE_NONE):
        txt_pdf[row[0]] = row[1]

out = csv.writer(sys.stdout)
out.writerow(('word count', 'file'))

for line in sys.stdin:
    txt_path = line.rstrip('\n')
    with open(txt_path) as f:
        count = 0
        for line in f:
            count += len(line.split())
    out.writerow((count, txt_pdf[txt_path]))
