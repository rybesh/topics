#! /usr/bin/env python3

import csv
import json
import os
import sys
from urllib.parse import quote
from utils import doc_name_to_fragment_id, doc_name_to_txt_path, strip_fixes

n_topics = int(sys.argv[1])

DOCS = int(5000 / n_topics)


def header(title='top documents per topic'):
    return f'''
    <!doctype html>
    <head>
    <meta charset=utf-8>
    <title>{title}</title>
    <style>
    .link {{
      display: inline-block;
      padding-left: 1em;
    }}
    .pt {{ padding-top: 1em }}
    .pw {{ padding: 0 0.25em }}
    .mb {{ margin-bottom: 1em }}
    .nav {{
      display: flex;
      width: 300px;
      justify-content: space-between;
      align-items: center;
    }}
    .spacer {{ height: 1000px }}
    .hidden {{ visibility: hidden }}
    .words {{
      list-style: none;
      padding: 0;
    }}
    .words li {{ display: inline }}
    .words li::after {{ content: ", " }}
    .words li:last-child::after {{ content: "" }}
    h3 {{
      display: inline-block;
      margin: 0;
      text-align: center;
    }}
    a {{ text-decoration: none; }}
    </style>
    <body>
    <div>
    <a href="/{n_topics}-topics.html">topic visualization and diagnostics</a>
    </div>
    <h1><a href="./">{n_topics} topics</a></h1>
    <h2>top {DOCS} documents per topic</h2>
    '''


def link(doc_name, txt_pdf):
    fragment = doc_name_to_fragment_id(doc_name)
    txt_path = doc_name_to_txt_path(doc_name)
    pdf_path = txt_pdf[txt_path]
    href = f'/{quote(pdf_path)}'
    anchor_text = strip_fixes(pdf_path, 'pdf/', '.pdf').replace('/', ' / ')
    return fragment, href, anchor_text


def red(scale):
    scale = round(255 * scale)
    return f'rgb(255,{255 - scale},{255 - scale})'


os.makedirs(f'topdocs/{n_topics}-topics', exist_ok=True)

with open(f'topdocs/{n_topics}-topics/index.html', 'w') as index:
    index.write(header())
    index.write('topics:<div style="max-width: 600px">')
    for topic_num in range(1, n_topics + 1):
        index.write((
            '<span class="link pt">'
            f'<a href="{topic_num}.html">{topic_num}</a>'
            '</span>\n'
        ))
    index.write('</div>')

with open(sys.argv[3]) as f:
    doc_topics = json.load(f)

with open(sys.argv[4]) as f:
    topic_words = json.load(f)

with open(sys.argv[5]) as f:
    txt_pdf = {}
    for row in csv.reader(f, delimiter='\t', quoting=csv.QUOTE_NONE):
        txt_pdf[row[0]] = row[1]

with open(sys.argv[2]) as f:
    next(f)
    last_topic_num = 0
    n_docs = 0
    page = None
    for line in f:
        topic_id, doc_id, doc_name, proportion = line.split()[0:4]
        topic_num = int(topic_id) + 1
        proportion = float(proportion)
        if topic_num == last_topic_num:
            n_docs += 1
        else:
            if page is not None:
                page.write('<div class="spacer"></div>')
                page.close()
            page = open(f'topdocs/{n_topics}-topics/{topic_num}.html', 'w')
            page.write(header(f'topic {topic_num}'))
            page.write('<div class="nav mb">')
            if topic_num > 1:
                page.write(
                    f'<a href="{topic_num - 1}.html">'
                    f'&lt; topic {topic_num - 1}</a>'
                )
            else:
                page.write('<span class="hidden">&lt; topic x</span>')
            page.write(f'<h3 id="{topic_num}">topic {topic_num}</h3>')
            if topic_num < n_topics:
                page.write(
                    f'<a href="{topic_num + 1}.html">'
                    f'topic {topic_num + 1} &gt;</a>'
                )
            else:
                page.write('<span class="hidden">topic x &gt;</span>')
            page.write('</div>')
            words = ''.join(
                [f'<li>{w}</li>' for w in topic_words[str(topic_num)]]
            )
            page.write(f'<ol class="words mb">{words}</ol>')
            viz = f'/viz/{n_topics}-topics/#topic={topic_num}&lambda=1&term='
            page.write((
                '<div class="mb">'
                f'<a target="_blank" href="{viz}">'
                'open topic in visualization'
                '</a>'
                '</div>'
            ))
            last_topic_num = topic_num
            n_docs = 1
        if n_docs > DOCS:
            continue
        fragment, href, anchor_text = link(doc_name, txt_pdf)
        page.write(
            f'<div id="{fragment}">'
            f'<span style="background-color: {red(proportion)}">'
            f'{proportion:.3f}'
            '</span>'
            f'<span class="link">'
            f'<a target="_blank" href="{href}">{anchor_text}</a>'
            '</span>'
        )
        for p, t in doc_topics.get(doc_name, []):
            if t == topic_num:
                continue
            page.write(
                '<span class="link">'
                f'<a href="{t}.html" class="pw"'
                f' style="background-color: {red(p)}">{t}</a>'
                '</span>'
            )
        page.write('</div>')
    if f is not None:
        page.write('<div class="spacer"></div>')
        page.close()
