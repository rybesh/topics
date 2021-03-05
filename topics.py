#! /usr/bin/env python3

import sys
import json
import shutil
import subprocess
from urllib.parse import quote
from utils import pdf_path_to_doc_name, doc_name_to_fragment_id, get_model_name

with open(sys.argv[1]) as f:
    doc_topics = json.load(f)

model = get_model_name(sys.argv[1])
pdf_path = sys.argv[2]
host = sys.argv[3]
port = sys.argv[4]

doc_name = pdf_path_to_doc_name(pdf_path)
fragment = quote(doc_name_to_fragment_id(doc_name))

if doc_name in doc_topics:

    open_cmd = shutil.which('open')
    if open_cmd is None:
        open_cmd = shutil.which('xdg-open')

    for p, t in doc_topics[doc_name]:
        url = f'http://{host}:{port}/topdocs/{model}/{t}.html#{fragment}'
        print(url)
        if open_cmd is not None:
            subprocess.run([open_cmd, url])
else:
    print(f'not among the top documents for any of the topics in {model}')
