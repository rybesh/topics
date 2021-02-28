TOOLS := git ant python3 pdftotext
MALLET := ./mallet/bin/mallet
PYTHON := ./venv/bin/python
PIP := ./venv/bin/pip

# where local web server should listen
HOST ?= 127.0.0.1
PORT ?= 5555

# machine specs, set in env
MEMORY ?= 12g
CPUS ?= $(shell sysctl hw.ncpu | cut -d ' ' -f 2)

# hyperparameter optimization settings
OPTIMIZATION := --optimize-interval 20 --optimize-burn-in 50 # keep this space

# where to put big intermediate and archived files
SCRATCH ?= .
MS ?= .

# check for the make version we need
need := 4.3
ok := $(filter $(need),$(firstword $(sort $(MAKE_VERSION) $(need))))
make_check := $(if $(ok),,\
	$(error Please use GNU make $(need) or later))

# check for the build tools we need
X := $(foreach tool,$(TOOLS),\
	$(if $(shell which $(tool)),,\
	$(error "Please install $(tool) and ensure it is in your path.")))

# utils for parsing model names
n_topics = $(word 1,$(subst -, ,$1))
optimize = $(word 2,$(subst -, ,$1))

# dump plaintext from pdfs
txt/dumped:
	mkdir -p txt
	find -L pdf \
	-name "*.pdf" \
	-not -path "**/Exclude from topic model/*" \
	-print0 \
	| xargs -0 -n1 ./dumptext.sh
	touch txt/dumped

# count words in each file
wordcounts.csv:
	echo '"word count",file' > $@
	find txt -name "*.txt" -print0 \
	| xargs -0 wc -w \
	| awk '{printf "%s,",$$1; $$1=""; printf "\"%s\"\n",$$0}' \
	| sed 's| txt/||' \
	>> $@

# install latest development version of MALLET
$(MALLET):
	git clone https://github.com/mimno/Mallet.git mallet
	cd mallet && ant test
	sed -i -e 's/MEMORY=1g/MEMORY=$(MEMORY)/g' $@

# turn text data into a MALLET feature sequence
txt.sequence: txt/dumped | $(MALLET)
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
	$(and $(call optimize,$*),$(OPTIMIZATION))\
	--output-state $@

# $(SCRATCH)/info is for possibly very large intermediate data files...

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
	--num-threads $(CPUS) \
	--input txt.sequence \
	--num-topics $(call n_topics,$*) \
	$(and $(call optimize,$*),$(OPTIMIZATION))\
	--input-state $< \
	--no-inference \
	--topic-word-weights-file $(SCRATCH)/info/$*-topics/topic-word-weights.tsv \
	--output-doc-topics $(SCRATCH)/info/$*-topics/doc-topics.tsv \
	--output-topic-docs $(SCRATCH)/info/$*-topics/topic-docs.txt \
	--diagnostics-file $(SCRATCH)/info/$*-topics/diagnostics.xml

$(SCRATCH)/info/%-topics/doc-topics.json: \
$(SCRATCH)/info/%-topics/topic-docs.txt \
| $(PYTHON)
	$(PYTHON) doc-topics.py $* $< > $@

$(SCRATCH)/info/%-topics/topic-words.json: \
$(SCRATCH)/info/%-topics/diagnostics.xml \
| $(PYTHON)
	$(PYTHON) topic-words.py $< > $@

# ...end # $(SCRATCH)/info

# archive intermediate files for mass storage
$(MS)/info.tar:
	tar -C $(SCRATCH) -cvf $@ info

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
| $(PYTHON)
	$(PYTHON) topdocs.py $* $^

# generate scripts for finding documents
%-topics: \
$(SCRATCH)/info/%-topics/doc-topics.json \
%-topics.html \
| $(PYTHON)
	./make-scripts.sh $@

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
	*-topics \
	*-topics.html \
	diagnostics/*-topics \
	index.html \
	info \
	models \
	txt/dumped \
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
models/%-topics.gz \
txt.sequence \
index.html \
%-topics.html \
topdocs/%-topics/index.html \
viz/%-topics/index.html \
diagnostics/%-topics/data.xml
