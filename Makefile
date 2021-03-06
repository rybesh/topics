TOOLS := git ant pdftotext
MALLET := ./mallet/bin/mallet
PYTHON := ./venv/bin/python
PIP := ./venv/bin/pip

# minimum versions required
NEED_MAKE_VERSION := 4.3
NEED_PYTHON_VERSION := 3.9

# where local web server should listen
HOST ?= 127.0.0.1
PORT ?= 5555

# machine specs, set in env
MEMORY ?= 12g
CPUS ?= $(if $(shell which nproc),$(shell nproc),$(shell sysctl hw.ncpu | cut -d ' ' -f 2))

# hyperparameter optimization settings
OPTIMIZATION := --optimize-interval 20 --optimize-burn-in 50 # keep this space

# the random seed to use when training models.
# 0 means use the clock, i.e. it will be different every time.
RANDOM_SEED := 0

# where to put big intermediate and archived files
SCRATCH ?= .
MS ?= .

# utility function for checking versions.
# first argument is the version we need, second argument is version we have.
# returns an empty string if the version we have is insufficient.
check_version = $(filter $1,$(firstword $(shell printf "%s\n" $2 $1 | sort -V)))

# check for the make version we need
$(if $(call check_version,$(NEED_MAKE_VERSION),$(MAKE_VERSION)),,\
	$(error Please use GNU make $(NEED_MAKE_VERSION) or later))

# check for the python version we need
$(if $(shell command -v python3),,\
	$(error Please install Python $(NEED_PYTHON_VERSION) or later \
	and ensure it is in your path))
PYTHON_VERSION=$(shell python3 -c \
'import sys; print("%d.%d" % sys.version_info[0:2])')
$(if $(call check_version,$(NEED_PYTHON_VERSION),$(PYTHON_VERSION)),,\
	$(error Please install Python $(NEED_PYTHON_VERSION) or later))

# check for the build tools we need
X := $(foreach tool,$(TOOLS),\
	$(if $(shell which $(tool)),,\
	$(error Please install $(tool) and ensure it is in your path)))

# utility functions for parsing model names.
# the argument passed to these functions is the first part of a model
# name, which is always 'n' (where n is the number of topics) or
# 'n-optimized'.  the n_topics function returns the 'n' part of the
# argument, while the optimize function returns the 'optimized' part
# (or an empty string there is no 'optimized' part).
n_topics = $(word 1,$(subst -, ,$1))
optimize = $(word 2,$(subst -, ,$1))

# $(SCRATCH)/info is for possibly very large intermediate data files...

# dump plain text from pdfs
$(SCRATCH)/info/txt-pdf.tsv: exclude.txt
	mkdir -p txt $(@D)
	find -L pdf -iname "*.pdf" \
	| grep -iv -f exclude.txt \
	| tr \\n \\0 \
	| xargs -0 -n1 ./dumptext.sh \
	> $@

$(SCRATCH)/info/instances.txt: txt.sequence
	mkdir -p $(@D)
	$(MALLET) info \
	--input txt.sequence \
	--print-instances > $@

$(SCRATCH)/info/features.txt: txt.sequence
	mkdir -p $(@D)
	$(MALLET) info \
	--input txt.sequence \
	--print-features > $@

$(SCRATCH)/info/feature-counts.tsv: txt.sequence
	mkdir -p $(@D)
	$(MALLET) info \
	--input txt.sequence \
	--print-feature-counts > $@

$(SCRATCH)/info/%-topics/topic-word-weights.tsv \
$(SCRATCH)/info/%-topics/doc-topics.tsv \
$(SCRATCH)/info/%-topics/topic-docs.txt \
$(SCRATCH)/info/%-topics/diagnostics.xml &: \
models/%-topics.gz
	mkdir -p $(SCRATCH)/info/$*-topics
	$(MALLET) train-topics \
	--input txt.sequence \
	--num-topics $(call n_topics,$*) \
	--input-state $< \
	--no-inference \
	--topic-word-weights-file $(SCRATCH)/info/$*-topics/topic-word-weights.tsv \
	--output-doc-topics $(SCRATCH)/info/$*-topics/doc-topics.tsv \
	--output-topic-docs $(SCRATCH)/info/$*-topics/topic-docs.txt \
	--diagnostics-file $(SCRATCH)/info/$*-topics/diagnostics.xml

$(SCRATCH)/info/%-topics/doc-topics.json: \
$(SCRATCH)/info/%-topics/topic-docs.txt
	python3 doc-topics.py $* $< > $@

$(SCRATCH)/info/%-topics/topic-words.json: \
$(SCRATCH)/info/%-topics/diagnostics.xml
	python3 topic-words.py $< > $@

# ...end # $(SCRATCH)/info

# archive intermediate files for mass storage
$(MS)/info.tar:
	tar -C $(SCRATCH) -cvf $@ info

# create an empty exclude file if none exists
exclude.txt:
	touch $@

# count words in each plain text file
wordcounts.csv: $(SCRATCH)/info/txt-pdf.tsv
	find txt -name "*.txt" \
	| python3 count-words.py $^ > $@

# install latest development version of MALLET
$(MALLET):
	git clone https://github.com/mimno/Mallet.git mallet
	cd mallet && ant test
	sed -i -e 's/MEMORY=1g/MEMORY=$(MEMORY)/g' $@

# turn text data into a MALLET feature sequence
txt.sequence: $(SCRATCH)/info/txt-pdf.tsv | $(MALLET)
	$(MALLET) import-dir \
	--input txt \
	--keep-sequence \
	--remove-stopwords \
	--output txt.sequence

# train topic model
models/%-topics.gz: txt.sequence
	mkdir -p models
	$(MALLET) train-topics \
	--num-threads $(CPUS) \
	--input txt.sequence \
	--num-topics $(call n_topics,$*) \
	--random-seed $(RANDOM_SEED) \
	$(and $(call optimize,$*),$(OPTIMIZATION))\
	--output-state $@

# install python and visualization libs
$(PYTHON):
	python3 -m venv venv
	$(PIP) install --upgrade pip
	$(PIP) install wheel
	$(PIP) install scikit-learn pyldavis

# generate topics visualization
viz/%-topics/index.html: \
$(SCRATCH)/info/instances.txt \
$(SCRATCH)/info/features.txt \
$(SCRATCH)/info/feature-counts.tsv \
$(SCRATCH)/info/%-topics/topic-word-weights.tsv \
$(SCRATCH)/info/%-topics/doc-topics.tsv \
| $(PYTHON)
	mkdir -p $(@D)
	$(PYTHON) viz.py $(SCRATCH)/info $(SCRATCH)/info/$*-topics > $@

# generate diagnostic visualization
diagnostics/%-topics/data.xml: \
$(SCRATCH)/info/%-topics/diagnostics.xml
	mkdir -p $(@D)
	cp $< diagnostics/$*-topics/data.xml
	ln -f diagnostics/index.html diagnostics/$*-topics/index.html
	ln -f diagnostics/style.css diagnostics/$*-topics/style.css
	ln -f diagnostics/code.js diagnostics/$*-topics/code.js

# create lists of top documents per topic
topdocs/%-topics/index.html: \
$(SCRATCH)/info/%-topics/topic-docs.txt \
$(SCRATCH)/info/%-topics/doc-topics.json \
$(SCRATCH)/info/%-topics/topic-words.json \
$(SCRATCH)/info/txt-pdf.tsv
	python3 topdocs.py $* $^

# generate scripts for finding documents
%-topics: \
$(SCRATCH)/info/%-topics/doc-topics.json \
%-topics.html
	./make-scripts.sh $@ $(HOST) $(PORT)

# generate html index pages
%-topics.html: \
topdocs/%-topics/index.html \
viz/%-topics/index.html \
diagnostics/%-topics/data.xml
	./make-indexes.sh $@ $(^D)

serve:
	python3 -m http.server $(PORT) -d . --bind $(HOST)

archive: $(MS)/info.tar

unarchive: $(MS)/info.tar
	tar -C $(SCRATCH) -xvf $<

clean: confirm
	rm -rf \
	$(SCRATCH)/info \
	*-topics \
	*-topics.html \
	diagnostics/*-topics \
	index.html \
	models \
	topdocs \
	topics \
	txt.sequence \
	viz \
	wordcounts.csv

confirm:
	@/bin/echo -n "Are you sure? [y/N] " && read ans && [ $${ans:-N} = y ]

superclean: confirm clean
	rm -rf txt mallet venv

.PHONY: \
archive \
clean \
confirm \
serve \
superclean \
unarchive

# don't delete these intermediate files
.PRECIOUS: \
$(SCRATCH)/info/%-topics/diagnostics.xml \
$(SCRATCH)/info/%-topics/doc-topics.json \
$(SCRATCH)/info/%-topics/doc-topics.tsv \
$(SCRATCH)/info/%-topics/topic-docs.txt \
$(SCRATCH)/info/%-topics/topic-word-weights.tsv \
$(SCRATCH)/info/%-topics/topic-words.json \
$(SCRATCH)/info/feature-counts.tsv \
$(SCRATCH)/info/features.txt \
$(SCRATCH)/info/instances.txt \
$(SCRATCH)/info/txt-pdf.tsv \
models/%-topics.gz \
txt.sequence \
index.html \
%-topics.html \
topdocs/%-topics/index.html \
viz/%-topics/index.html \
diagnostics/%-topics/data.xml
