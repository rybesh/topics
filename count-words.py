#!/usr/bin/env python3

import sys
import csv

# the txt paths coming from stdin will not have been normalized,
# so we don't want to use utils.load_txt_path_to_pdf_path_mappings,
# which normalizes its keys
txt_pdf = {}
with open(sys.argv[1]) as f:
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
