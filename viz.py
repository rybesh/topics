import sys
import csv
import os.path
import pyLDAvis
import numpy as np
from joblib import cpu_count


def log(message):
    sys.stderr.write(message + '\n')


def normalize(weights):
    s = sum(weights)
    return [w / s for w in weights]


def load_topic_term_dists(filename):
    log('loading topic-term distributions...')
    dists = []
    with open(filename) as f:
        reader = csv.reader(f, delimiter="\t")
        topic = weights = None
        for row in reader:
            if not row[0] == topic:
                if weights is not None:
                    dists.append(normalize(weights))
                topic = row[0]
                weights = []
            weights.append(float(row[2]))
            topic = row[0]
        if weights is not None:
            dists.append(normalize(weights))
    return dists


def load_doc_topic_dists(filename):
    log('loading document-topic distributions...')
    dists = []
    with open(filename) as f:
        reader = csv.reader(f, delimiter="\t")
        for row in reader:
            dists.append([float(x) for x in row[2:]])
    return dists


def load_doc_lengths(filename):
    log('loading document lengths...')
    lengths = []
    with open(filename) as f:
        length = None
        for line in f:
            if len(line.strip()) == 0:
                continue
            if line.startswith('file:'):
                if length is not None:
                    lengths.append(length)
                length = 1
            else:
                length = int(line.split(':')[0])
        if length is not None:
            lengths.append(length)
    return lengths


def load_vocab(filename):
    log('loading vocabulary...')
    vocab = []
    with open(filename) as f:
        for line in f:
            vocab.append(line.strip())
    return vocab


def load_term_frequency(filename):
    log('loading term frequencies...')
    counts = []
    with open(filename) as f:
        reader = csv.reader(f, delimiter="\t")
        for row in reader:
            counts.append(int(row[1]))
    return counts


def load_mallet_model(corpus_info_path, topics_info_path):
    return {
        'doc_lengths': load_doc_lengths(
            os.path.join(corpus_info_path, 'instances.txt')),
        'vocab': load_vocab(
            os.path.join(corpus_info_path, 'features.txt')),
        'term_frequency': load_term_frequency(
            os.path.join(corpus_info_path, 'feature-counts.tsv')),
        'topic_term_dists': load_topic_term_dists(
            os.path.join(topics_info_path, 'topic-word-weights.tsv')),
        'doc_topic_dists': load_doc_topic_dists(
            os.path.join(topics_info_path, 'doc-topics.tsv')),

        'sort_topics': False,
        'mds': 'tsne',  # algorithm for measuring distance between topics
    }


corpus_info_path = sys.argv[1]
topics_info_path = sys.argv[2]

model = load_mallet_model(corpus_info_path, topics_info_path)

log('topic-term shape: %s' % str(np.array(model['topic_term_dists']).shape))
log('doc-topic shape: %s' % str(np.array(model['doc_topic_dists']).shape))
log('doc lengths shape: %s' % str(np.array(model['doc_lengths']).shape))

log('using %s cores' % model.get('n_jobs', cpu_count()))
log('measuring topic distance using %s' % model['mds'])

log('preparing visualization...')
data = pyLDAvis.prepare(**model)

log('writing html...')
html = pyLDAvis.prepared_data_to_html(data)

print(html)
