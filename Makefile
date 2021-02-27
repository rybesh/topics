TOOLS = git ant python3
MALLET = ./mallet/bin/mallet
PYTHON = ./venv/bin/python

# machine specs, set in env
MEMORY ?= 12g
CPUS ?= $(shell sysctl hw.ncpu | cut -d ' ' -f 2)

# hyperparameter optimization settings
OPTIMIZATION = --optimize-interval 20 --optimize-burn-in 50 # keep this space

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

txt/dumped:
	mkdir -p txt
	find -L pdf \
	-name "*.pdf" \
	-not -path "**/Exclude from topic model/*" \
	-print0 \
	| xargs -0 -n1 ./dumptext.sh
	touch txt/dumped

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

$(SCRATCH)/info:
	mkdir -p $@

$(SCRATCH)/info/instances.txt: txt.sequence | $(SCRATCH)/info
	$(MALLET) info \
	--input txt.sequence \
	--print-instances > $@

$(SCRATCH)/info/features.txt: txt.sequence | $(SCRATCH)/info
	$(MALLET) info \
	--input txt.sequence \
	--print-features > $@

$(SCRATCH)/info/feature-counts.tsv: txt.sequence | $(SCRATCH)/info
	$(MALLET) info \
	--input txt.sequence \
	--print-feature-counts > $@

$(SCRATCH)/info/%-topics/topic-word-weights.tsv \
$(SCRATCH)/info/%-topics/doc-topics.tsv \
$(SCRATCH)/info/%-topics/topic-docs.txt \
$(SCRATCH)/info/%-topics/diagnostics.xml &: \
models/%-topics.gz txt.sequence
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
$(SCRATCH)/info/%-topics/topic-docs.txt
	$(PYTHON) doc-topics.py $* $< > $@

# ...end # $(SCRATCH)/info

$(MS)/info.tar:
	tar -C $(SCRATCH) -cvf $@ info

$(PYTHON):
	python3 -m venv venv
	./venv/bin/pip install --upgrade pip
	./venv/bin/pip install \
	wheel \
	scikit-learn \
	git+https://github.com/rybesh/pyLDAvis.git

# generate topics visualization
viz/%-topics/index.html: \
$(SCRATCH)/info/instances.txt \
$(SCRATCH)/info/features.txt \
$(SCRATCH)/info/feature-counts.tsv \
$(SCRATCH)/info/%-topics/topic-word-weights.tsv \
$(SCRATCH)/info/%-topics/doc-topics.tsv \
| viz/%-topics $(PYTHON)
	mkdir -p viz/$*-topics
	$(PYTHON) viz.py $(SCRATCH)/info $(SCRATCH)/info/$*-topics > $@

# generate diagnostic visualization
diagnostics/%-topics/index.html: \
$(SCRATCH)/info/%-topics/diagnostics.xml
	mkdir -p diagnostics/$*-topics
	cp $< diagnostics/$*-topics/data.xml
	ln -f diagnostics/index.html diagnostics/$*-topics/index.html
	ln -f diagnostics/style.css diagnostics/$*-topics/style.css
	ln -f diagnostics/code.js diagnostics/$*-topics/code.js

# create lists of top documents per topic
topdocs/%-topics/index.html: \
$(SCRATCH)/info/%-topics/topic-docs.txt \
$(SCRATCH)/info/%-topics/doc-topics.json \
| $(PYTHON)
	$(PYTHON) topdocs.py $* $^

%-topics: $(SCRATCH)/info/%-topics/doc-topics.json | $(PYTHON)
	echo '#! /bin/sh' > $@
	echo './topics.py info/$*-topics/doc-topics.json "$$1"' >> $@
	chmod +x $@

%-topics.html: \
viz/%-topics/index.html \
topdocs/%-topics/index.html \
diagnostics/%-topics/index.html \
%-topics \
FORCE
	echo '<!doctype html>' > $@
	echo '<meta charset=utf-8>' >> $@
	echo '<title>$* topics</title>' >> $@
	echo '<body style="max-width: 800px">' >> $@
	echo '<ul>' >> $@
	echo '<li><a href="$(word 1,$(^D))">visualization</a>' >> $@
	echo '<li><a href="$(word 2,$(^D))">top documents per topic</a>' >> $@
	echo '<li><a href="$(word 3,$(^D))">diagnostics</a>' >> $@
	echo '</ul>' >> $@

serve:
	python3 -m http.server 5555 -d . --bind 127.0.0.1

archive: $(MS)/info.tar

unarchive: $(MS)/info.tar
	tar -C $(SCRATCH) -xvf $<

clean:
	rm -f txt/dumped wordcounts.csv txt.sequence *-topics.html

confirm:
	@/bin/echo -n "Are you sure? [y/N] " && read ans && [ $${ans:-N} = y ]

superclean: confirm clean
	rm -rf txt mallet venv

superduperclean: superclean
	rm -rf models viz topdocs diagnostics

FORCE:

.PHONY: \
serve \
archive \
unarchive \
clean \
superclean \
superduperclean \
confirm

# expensive-to-generate files
.PRECIOUS: \
txt.sequence \
models/%-topics.gz \
$(SCRATCH)/info/instances.txt \
$(SCRATCH)/info/features.txt \
$(SCRATCH)/info/feature-counts.tsv \
$(SCRATCH)/info/%-topics/topic-word-weights.tsv \
$(SCRATCH)/info/%-topics/doc-topics.tsv \
$(SCRATCH)/info/%-topics/doc-topics.json \
$(SCRATCH)/info/%-topics/topic-docs.txt \
$(SCRATCH)/info/%-topics/diagnostics.xml \
%-topics \
viz/%-topics/index.html \
topdocs/%-topics/index.html \
diagnostics/%-topics/index.html
