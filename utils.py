import os
import re
from urllib.parse import unquote

ENCODINGS = (
    ('%', '%25'),
    ('"', '%22'),
    ('#', '%23'),
    ('<', '%3C'),
    ('>', '%3E'),
    ('?', '%3F'),
    ('[', '%5B'),
    ('\\', '%5C'),
    (']', '%5D'),
    ('^', '%5E'),
    ('`', '%60'),
    ('{', '%7B'),
    ('|', '%7C'),
    ('}', '%7D'),
)


# emulate java's idiosyncratic URI encoding
def escape(s):
    escaped = s
    for character, encoded in ENCODINGS:
        escaped = escaped.replace(character, encoded)
    return escaped


def strip_prefix(s, prefix):
    return re.sub(r'^%s' % prefix, '', s, flags=re.IGNORECASE)


def strip_suffix(s, suffix):
    return re.sub(r'%s$' % suffix, '', s, flags=re.IGNORECASE)


# case-insensitive prefix and suffix removal
def strip_fixes(s, prefix, suffix):
    _s = s
    _s = strip_prefix(_s, prefix)
    _s = strip_suffix(_s, suffix)
    return _s


# convert a mallet document name to a relative plain text file path
def doc_name_to_txt_path(doc_name):
    return strip_prefix(unquote(doc_name), f'file:{os.getcwd()}/')


# convert a mallet document name to a URL fragment identifier
def doc_name_to_fragment_id(doc_name):
    return strip_fixes(doc_name, f'file:{os.getcwd()}/txt/', '.txt')


# convert a relative pdf file path to a mallet document name
def pdf_path_to_doc_name(pdf_path):
    txt_path = pdf_path_to_txt_path(pdf_path)
    return 'file:' + escape(f'{os.getcwd()}/{txt_path}')


# convert a relative pdf path to a relative txt path
def pdf_path_to_txt_path(pdf_path):
    path = strip_fixes(pdf_path, 'pdf/', '.pdf')
    path_no_spaces = path.replace(' ', '_')
    return f'txt/{path_no_spaces}.txt'
