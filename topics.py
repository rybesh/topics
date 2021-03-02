#! /usr/bin/env python3

import sys
import json
import re
import subprocess
from urllib.parse import quote
from utils import pdf_path_to_doc_name, doc_name_to_fragment_id

with open(sys.argv[1]) as f:
    doc_topics = json.load(f)

model = re.match(r'.*\/(\d+-topics)\/.*', sys.argv[1])[1]
pdf_path = sys.argv[2]
host = sys.argv[3]
port = sys.argv[4]

doc_name = pdf_path_to_doc_name(pdf_path)
fragment = quote(doc_name_to_fragment_id(doc_name))

for p, t in doc_topics[doc_name]:
    subprocess.run([
        'open',
        f'http://{host}:{port}/topdocs/{model}/{t}.html#{fragment}'
    ])
