#!/usr/bin/env bash

prettify () {
    PRETTY="${1%.html}"
    PRETTY="${PRETTY//-/ }"
    echo "$PRETTY"
}

TITLE=$(prettify "$1")

cat > "$1" <<EOF
<!doctype html>
<meta charset=utf-8>
<title>$TITLE</title>
<style>
a { text-decoration: none; }
</style>
<body>
<div><a href="/">all topic models</a></div>
<h1>$TITLE</h1>
<ul>
<li><a href="$2">top documents per topic</a>
<li><a target="_blank" href="$3">visualization</a>
<li><a target="_blank" href="$4">diagnostics</a>
</ul>
EOF

cat > index.html <<EOF
<!doctype html>
<meta charset=utf-8>
<title>topic models</title>
<style>
a { text-decoration: none; }
</style>
<body>
<h1>topic models</h1>
<ul>
EOF

# shellcheck disable=2012
for index in $(ls -- *-topics.html | sort -n)
do
    anchor=$(prettify "$index")
    echo "<li><a href=\"$index\">$anchor</a>" >> index.html
done

echo "</ul>" >> index.html
