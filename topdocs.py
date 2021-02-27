#! /usr/bin/env python3

import sys
import os
import json

n_topics = int(sys.argv[1])

DOCS = int(5000 / n_topics)


def header(title='top documents per topic'):
    return (
        '<!doctype html>'
        '<head>'
        '<meta charset=utf-8>'
        f'<title>{title}</title>'
        '<style>'
        '.link { padding-left: 1em }'
        '.nav {'
        '  display: flex;'
        '  width: 300px;'
        '  justify-content: space-between;'
        '  align-items: center;'
        '  margin-bottom: 2em;'
        '}'
        '.spacer { height: 1000px }'
        'h2 {'
        '  display: inline-block;'
        '  margin: 0;'
        '  text-align: center;'
        '}'
        'a {'
        '  text-decoration: none;'
        '  padding: 0 0.25em;'
        '}'
        '</style>'
        f'<body><h1>top {DOCS} documents per topic</h1>'
    )


def link(f):
    path = (
        f.split('/')[-1]
        .replace('__', '/')
        .replace('_', ' ')
        .removesuffix('.txt')
    )
    return f'/pdf/{path}.pdf', path


def red(scale):
    scale = round(255 * scale)
    return f'rgb(255,{255 - scale},{255 - scale})'


os.makedirs(f'topdocs/{n_topics}-topics', exist_ok=True)

with open(f'topdocs/{n_topics}-topics/index.html', 'w') as index:
    index.write(header())
    index.write('topics: ')
    for topic_num in range(1, n_topics + 1):
        index.write(f'<a href="{topic_num}.html">{topic_num}</a>\n')

with open(sys.argv[3]) as f:
    doc_topics = json.load(f)

with open(sys.argv[2]) as f:
    next(f)
    last_topic_num = 0
    n_docs = 0
    page = None
    for line in f:
        topic, doc, filename, proportion = line.split()[0:4]
        topic_num = int(topic) + 1
        proportion = float(proportion)
        if topic_num == last_topic_num:
            n_docs += 1
        else:
            if page is not None:
                page.write('<div class="spacer"></div>')
                page.close()
            page = open(f'topdocs/{n_topics}-topics/{topic_num}.html', 'w')
            page.write(header(f'topic {topic_num}'))
            page.write('<div class="nav">')
            if topic_num > 1:
                page.write(
                    f'<a href="{topic_num - 1}.html">'
                    f'&lt; topic {topic_num - 1}</a>'
                )
            else:
                page.write('<span></span>')
            page.write(f'<h2 id="{topic_num}">topic {topic_num}</h2>')
            if topic_num < n_topics:
                page.write(
                    f'<a href="{topic_num + 1}.html">'
                    f'topic {topic_num + 1} &gt;</a>'
                )
            else:
                page.write('<span></span>')
            page.write('</div>')
            last_topic_num = topic_num
            n_docs = 1
        if n_docs > DOCS:
            continue
        href, anchor = link(filename)
        page.write(
            f'<div id="{anchor}">'
            f'<span style="background-color: {red(proportion)}">'
            f'{proportion:.3f}'
            '</span>'
            f'<span class="link"><a href="{href}">{anchor}</a></span>'
        )
        for p, t in doc_topics.get(filename, []):
            if t == topic_num:
                continue
            page.write(
                '<span class="link">'
                f'<a href="{t}.html" style="background-color: {red(p)}">{t}</a>'
                '</span>'
            )
        page.write('</div>')
    if f is not None:
        page.write('<div class="spacer"></div>')
        page.close()
