# Topic model a library of PDFs

1. Put PDFs in a subdirectory called `pdf`
1. Build a topic model: `make 50-topics` (replace 50 with how many topics you want)
1. `make serve` to run a local web server
1. open `http://127.0.0.1:5555/50-topics.html` to browse the topic model
1. `./50-topics [path-to-pdf]` will show that document in the context of the model
