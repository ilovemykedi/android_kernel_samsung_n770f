#!/bin/sh
# oct.sh FILE N : write hunk N as ours + "}" + blank + theirs (two functions whose shared closing brace follows the hunk)
f=$1; n=$2; S=/tmp/claude-0/-root/cfcc6776-b813-474a-9fd2-5db445cebaab/scratchpad
awk -v n=$n '/^<<<<<<< /{k++} k==n' "$f" | awk 'NR>1 && /^=======/{exit} NR>1' > $S/oct_o
awk -v n=$n '/^<<<<<<< /{k++} k==n' "$f" | awk '/^=======/{f=1;next} /^>>>>>>>/{exit} f' > $S/oct_t
( cat $S/oct_o; printf '}\n\n'; cat $S/oct_t ) > $S/oct_$n
echo $S/oct_$n
