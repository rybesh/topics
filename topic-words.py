#! /usr/bin/env python3

import sys
import json
from xml.dom import pulldom
from collections import defaultdict

topic_words = defaultdict(list)

topic_num = 0
in_word = False
doc = pulldom.parse(sys.argv[1])
for event, node in doc:
    if event == pulldom.START_ELEMENT:
        if node.tagName == 'topic':
            topic_num = int(node.getAttribute('id')) + 1
        if node.tagName == 'word':
            in_word = True
    if event == pulldom.CHARACTERS and in_word:
        topic_words[topic_num].append(node.data)
        in_word = False

json.dump(topic_words, sys.stdout)
