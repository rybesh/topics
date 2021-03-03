#! /usr/bin/env python3

import sys
import json
from utils import get_n_topics
from collections import defaultdict

n_topics = get_n_topics(sys.argv[1])

DOCS = int(5000 / n_topics)

doc_topics = defaultdict(list)

with open(sys.argv[2]) as f:
    next(f)
    last_topic_num = 0
    n_docs = 0
    for line in f:
        topic_id, doc_id, doc_name, proportion = line.split()[0:4]
        topic_num = int(topic_id) + 1
        proportion = float(proportion)
        if topic_num == last_topic_num:
            n_docs += 1
        else:
            last_topic_num = topic_num
            n_docs = 1
        if n_docs > DOCS:
            continue
        doc_topics[doc_name].append((proportion, topic_num))

for topics in doc_topics.values():
    topics.sort(reverse=True)

json.dump(doc_topics, sys.stdout)
