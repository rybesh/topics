#! /bin/bash

PDFPATH="$1"
TXTPATH="$1"

# strip 'pdf/' prefix
TXTPATH=${TXTPATH#pdf/}

# strip '.pdf' suffix
TXTPATH=${TXTPATH%.[pP][dD][fF]}

# replace spaces with underscores
TXTPATH=${TXTPATH// /_}

# add txt prefix and suffix
TXTPATH="txt/${TXTPATH}.txt"

# dump the pdf only if needed
if [ ! -f "$TXTPATH" ]; then
    echo "Dumping $PDFPATH" > /dev/stderr
    mkdir -p "$(dirname "$TXTPATH")"
    pdftotext -q "$PDFPATH" "$TXTPATH"
fi

# write txt path to pdf path mapping to stdout
printf "%s\t%s\n" "$TXTPATH" "$PDFPATH"
