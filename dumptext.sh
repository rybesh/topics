#! /bin/bash

PDFPATH="$1"
FILENAME=${PDFPATH//\//__}
FILENAME=${FILENAME// /_}
FILENAME=${FILENAME#pdf__}
FILENAME=${FILENAME%pdf}
TXTPATH="txt/${FILENAME}txt"

if [ ! -f "$TXTPATH" ]; then
    echo "Dumping $PDFPATH"
    pdftotext -q "$PDFPATH" "$TXTPATH"
fi
