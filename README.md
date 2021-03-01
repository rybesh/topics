# Topic model a library of PDFs

This is a Unix-style workflow for [topic modeling](https://www.youtube.com/watch?v=gN2x_KjJI1o) a personal library
of PDFs. It should work on macOS and Linux.

If you find something in these instructions unclear, or something
doesn't work for you, or you have a suggestion for improving this
workflow, please [file an issue](https://github.com/rybesh/topics/issues).

## Prerequisites

These instructions assume some basic familiarity with the macOS
terminal or Linux shell.

Depending on how many PDFs you have, you may need a computer that has
a good amount of RAM and a CPU with multiple cores. On my 2019 laptop
with a 8 core Intel CPU and 16GB of RAM, building and visualizing a
50-topic model of ~5000 PDFs takes about 15 minutes. Building and
visualizing a 200-topic model takes about an hour. If you have more
PDFs than that, or don't have that many cores or that much RAM, you
might want to run this on an on-demand cloud compute server—but doing
that is beyond the scope of these instructions.

Wherever you run this, you will need recent versions of the following
software: [GNU make](https://www.gnu.org/software/make/) (version 4.3 or later) [pdftotext](https://en.wikipedia.org/wiki/Pdftotext),
[git](https://git-scm.com), [ant](https://ant.apache.org), and [Python](https://www.python.org) (version 3.6 or later).

On macOS, all of these can be installed using [Homebrew](https://brew.sh). After
installing Homebrew, execute the following command in the terminal to
install all the prerequisites:

```
brew install make poppler git ant python3
```

(`poppler` is the name of the package that installs `pdftotext`.)

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
make 50-topics
```

If you're using macOS and you installed GNU make using Homebrew, make
is installed as `gmake`, so you'll need to instead use:

```
gmake 50-topics
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
make 111-topics
```

You can build multiple topic models with one command (each will be
built sequentially):

```
make 50-topics 100-topics
```

By default MALLET will use 12G of RAM; if you don't have that much (or
you have more) you can specify how much RAM to use:

```
MEMORY=8g make 50-topics
```

Note that the less RAM MALLET uses, the more time topic modeling will
take (and the more it uses, the less time it will take).

## Browse your topic models

Run a local web server for browsing the topic models with the command:

```
make serve
```

This will run a server on http://localost:5555, which you can visit
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

On macOS, you can find a specific document in the models you've built
by using the `topics` shell script in the `topics` directory. Give it
the path to a PDF, and it will open every top documents list in which
that document appears:

```
./topics pdf/Desktop/TO-READ/an-interesting-article.pdf
```

This command will work on Linux too, but first you need to install
[xdg-open](https://linux.die.net/man/1/xdg-open) (it may already be installed) and add the following to
your `~/.aliases`:

```
alias open='xdg-open'
```

For an explanation of the topic structure visualization, see the
[pyLDAvis documentation](https://pyldavis.readthedocs.io/en/latest/readme.html#usage).

For an explanation of the diagnostics tool, see the [MALLET
documentation](http://mallet.cs.umass.edu/diagnostics.php).

## Rebuild your topic models

If you add new PDFs to your PDF directories, you'll need to rebuild
your topic models. To do this use the command:

```
make clean 50-topics
```

Again, `50` can be replaced with however many topics you want. Be sure
to rebuild all the existing models if you want them to incorporate the
new PDFs.

This command will only convert the new PDFs to plain text, skipping any
PDFs that have already been converted. If you want to start completely
from scratch, including re-converting all your PDFs and re-installing
MALLET and pyLDAvis, use the command:

```
make superclean 50-topics
```

Note that **you will not get the same set of topics** when you rebuild
your models! This is expected: topic modeling involves random
sampling, which produces different (but comparable) results each time.

For exploring a library of PDFs, this is a feature, not a bug: you can rebuild your topic models several times, looking to see what kinds of interesting clusters are turned up.

However, if you need reproducibility, you can edit the Makefile to
[add the `--random-seed` option to the MALLET `train-topics`
command](https://stackoverflow.com/questions/18050891/bin-mallet-train-topics-getting-different-results-at-every-instance) (below where it says `# train topic model`).

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
