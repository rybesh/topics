# Topic model a library of PDFs

This is a Unix-style workflow for [topic modeling](https://www.youtube.com/watch?v=gN2x_KjJI1o) a personal
library of PDFs using [MALLET](http://mallet.cs.umass.edu). It should work on macOS and Linux.

If you find something in these instructions unclear, or something
doesn't work for you, or you have a suggestion for improving this
workflow, please [file an issue](https://github.com/rybesh/topics/issues).

## Prerequisites

These instructions assume some basic familiarity with the macOS
terminal or Linux shell.

Depending on how many PDFs you have, you may need a computer that has
a good amount of RAM and a CPU with multiple cores. On my 2019 laptop
with a 8 core Intel CPU and 16GB of RAM, building and visualizing a
50-topic model of around 5,000 PDFs, having a total of about 20
million words, takes about 15 minutes. Building and visualizing a
200-topic model takes about an hour. (Most of that time is spent
generating the visualization, not building the topic model.)

If you have more PDFs than that, or don't have that many cores or that
much RAM, you might want to run this on an on-demand cloud compute
server—but doing that is beyond the scope of these instructions.

Wherever you run this, you will need recent versions of the following
software: [GNU make](https://www.gnu.org/software/make/) (version 4.3 or later), [Python](https://www.python.org) (version
3.8 or later), [pdftotext](https://en.wikipedia.org/wiki/Pdftotext), [git](https://git-scm.com), and [ant](https://ant.apache.org).

(It probably will work with an earlier version of Python 3, but I
haven't tested this. If you want to try it with an earlier version,
set the value of `NEED_PYTHON_VERSION` in the [Makefile](https://github.com/rybesh/topics/blob/main/Makefile#L8) to that
version, and then please let me know if it works by [filing an
issue](https://github.com/rybesh/topics/issues).)

On macOS, all of these can be installed using [Homebrew](https://brew.sh). After
installing Homebrew, execute the following command in the terminal to
install all the prerequisites:

```
brew install make python3 poppler git ant
```

(`poppler` is the name of the package that installs `pdftotext`.)

On Ubuntu Linux 20.10 (Groovy Gorilla) or later, these prerequisites
can be installed using `apt-get`:

```
sudo apt-get install make python3 python3-venv poppler-utils git ant
```

Note that on Ubuntu you must install `python3-venv` in addition to
`python3`.

## Make a local copy of this repository

Either [clone this repository](https://docs.github.com/en/github/creating-cloning-and-archiving-repositories/cloning-a-repository), or [download the ZIP file](https://github.com/rybesh/topics/archive/main.zip) of
this repository and unzip it someplace. Either way you should end up
with a directory called `topics` on your computer.

## Collect your PDFs

Visit the `topics` directory in your terminal or shell:

```
cd /wherever/you/put/topics
```

Create a subdirectory called `pdf`:

```
mkdir pdf
```

Then you can put all your PDFs in this subdirectory. If you don't want
to disturb the organization of your PDFs, you can leave them where
they are and use [symbolic links](https://wiki.debian.org/SymLink) to point to them. For example, if
you keep your PDFs in `~/Documents/Papers` and `~/Desktop/TO-READ`

```
cd pdf
ln -s ~/Documents/Papers
ln -s ~/Desktop/Papers
```

The directory structure inside `pdf` (or inside the directories
pointed to by symbolic links within `pdf`) doesn't matter. Any files
ending in `.pdf`, no matter how deeply nested, will be found and
indexed and all other files will be ignored.

If there are PDFs you want to exclude from your topic models, you can
create a file called `exclude.txt` in the `topics` directory, and list
patterns there matching any filenames you want to exclude. For example
if your `exclude.txt` file contained:

```
michel foucault
draft
```

… then any PDFs with filenames containing the name “Michel Foucault”
or the word “draft” will be excluded. You can also use [basic regular
expressions](https://www.gnu.org/software/grep/manual/html_node/Basic-vs-Extended.html). Matching is case-insensitive.

## Build your topic models

Assuming you’re still visiting the `topics` directory in your terminal
or shell, you can build a topic model with 50 topics with the command:

```
./build 50-topics
```

This will

1. convert all your PDFs to plain text files in a subdirectory called `txt`
1. download and install the [MALLET](http://mallet.cs.umass.edu/) topic modeling software
1. build a topic model with 50 topics
1. create an interactive visualization of the topics using [pyLDAvis](https://github.com/bmabey/pyLDAvis)
1. create a set of web pages for browsing the model

`50` can be changed to whatever you want; to build a model with 111
topics use the command:

```
./build 111-topics
```

“Hyperparameter optimization” is a MALLET option that allows some
topics to be more prominent than others, which can sometimes result in
better models. To build an optimized model, put the word `-optimized`
after the number of topics you want:

```
./build 50-optimized-topics
```

You can build multiple topic models with one command (each will be
built sequentially):

```
./build 50-topics 50-optimized-topics 100-topics 100-optimized-topics
```

By default MALLET will use 12G of RAM; if you don't have that much (or
you have more) you can specify how much RAM to use:

```
MEMORY=8g ./build 50-topics
```

Note that the less RAM MALLET uses, the more time topic modeling will
take (and the more it uses, the less time it will take).

## Browse your topic models

Run a local web server for browsing the topic models with the command:

```
make serve
```

This will run a server on http://localhost:5555, which you can visit
with a web browser. If something else is already running on port 5555,
you can change the port:

```
PORT=12345 make serve
```

When you visit http://localhost:5555 you'll see links to each of the
models you've built. For each model, you can see

* lists of the top documents per topic
* a visualization of the topic structure
* diagnostics tool for troubleshooting the model

The lists of the top documents per topic show the strength of
association with the topic in a column along the left side of the
page. Clicking on a document in the list will open it in the
browser. For documents that are in the list of top documents for more
than one topic, links to the other topics appear after the link to the
document.

You can find a specific document in the models you've built by using
the `topics` shell script in the `topics` directory. Give it the path
to a PDF, and it will print the URL of and (if it can) open in a
browser every top documents list in which that document appears:

```
./topics pdf/Desktop/TO-READ/an-interesting-article.pdf
```

Note that if you change the port on which the local web server runs
from the default of `5555`, you'll need to rebuild the shell scripts
for finding specific documents. Assuming you've built topic models
with 50, 100, and 200 topics, you can delete and rebuild the shell
scripts as follows:

```
rm -f topics 50-topics 100-topics 200-topics
./build 50-topics 100-topics 200-topics
```

For an explanation of the topic structure visualization, see the
[pyLDAvis documentation](https://pyldavis.readthedocs.io/en/latest/readme.html#usage).

For an explanation of the diagnostics tool, see the [MALLET
documentation](http://mallet.cs.umass.edu/diagnostics.php).

## Rebuild your topic models

If you add new PDFs to your PDF directories, you'll need to rebuild
your topic models. To do this use the command:

```
./rebuild 50-optimized-topics
```

**This will delete all existing models** and then build an optimized
50-topic model.

If you only want to rebuild a specific model, without deleting all
existing models, you can delete just that model and then build it:

```
./delete 50-topics
./build 50-topics
```

Note that if you've added new PDFs, only the models that are rebuilt
will incorporate them, so most of the time you're going to want to use
`rebuild` to rebuild all of your models.

These commands (`rebuild` or `delete` followed by `build`) will only
convert the new PDFs to plain text, skipping any PDFs that have
already been converted. If you want to start completely from scratch,
including re-converting all your PDFs and re-installing MALLET and
pyLDAvis, use the command:

```
make superclean 50-topics
```

Note that **you will not get the same set of topics** when you rebuild
your models! This is expected: topic modeling involves random
sampling, which produces different (but comparable) results each time.

For exploring a library of PDFs, this is a feature, not a bug: you can
rebuild your topic models several times, looking to see what kinds of
interesting clusters are turned up.

However, if you need reproducibility, when you build your topic models
you can specify a [random seed](https://en.wikipedia.org/wiki/Random_seed) for MALLET to use as follows:

```
RANDOM_SEED=7 ./build 50-topics
```

The value of `RANDOM_SEED` can be any positive integer (not zero). 

If you use the same `RANDOM_SEED` value every time you build the
models, you should get the same results each time.

## Troubleshooting

Some PDFs, such as scanned PDFs that have not had OCR run on them, may
not have any readable text in them, meaning that the plain text
versions of these files will be empty. You can check if this is the
case for any of your PDF files by running this command:

```
make wordcounts.csv
```

This will generate a [CSV](https://simple.wikipedia.org/wiki/Comma-separated_values) file listing the word count for each
plain text file created from your PDFs. Open the CSV in the
spreadsheet software of your choice and sort by word count. Files with
zero or very few words should be checked to see if the PDF needs to
have OCR run on it.

You may find that one or more of your topics seems to consist of
gibberish. This is usually a sign that OCR has failed, producing a
bunch of unreadable symbols instead of readable text. This is often
due to a problem with embedded fonts in the PDF file. Using Adobe
Acrobat Pro DC to [convert fonts to outlines](https://www.copperbottomdesign.com/blog/converting-fonts-to-outlines) before running OCR
can fix this.

You can use the diagnostics tool to find other kinds of “problematic”
topics—see the [MALLET documentation](http://mallet.cs.umass.edu/diagnostics.php).
