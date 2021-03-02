#! /bin/bash

cat > "$1" <<EOF
#! /bin/sh
./topics.py info/$1/doc-topics.json "\$1" $2 $3
EOF

# shellcheck disable=2012
cat > topics <<EOF
for script in \$(ls -- *-topics | sort -n)
do
        ./\$script "\$1"
done
EOF

chmod +x "$1" topics
