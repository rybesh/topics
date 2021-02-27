#! /usr/bin/env python3

import sys
import json
import re
import subprocess
from urllib.parse import quote

HOST = '127.0.0.1:5555'


# deal with quirks in mallet's url encoding
def _quote(s):
    return quote(s).replace('%2B', '+')


with open(sys.argv[1]) as f:
    doc_topics = json.load(f)

anchor = (
    sys.argv[2]
    .removeprefix('pdf/')
    .removesuffix('.pdf')
)

filename = (
    anchor
    .replace('/', '__')
    .replace(' ', '_')
)

model = re.match(r'.*\/(\d+-topics)\/.*', sys.argv[1])[1]

for p, t in doc_topics[
        (f'file:/Users/ryanshaw/Code/topics/txt/{_quote(filename)}.txt')
]:
    subprocess.run(
        ['open', f'http://{HOST}/topdocs/{model}/{t}.html#{quote(anchor)}']
    )
