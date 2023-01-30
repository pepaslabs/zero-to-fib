#!/bin/bash

# run-tests.sh: run all of the unit tests.

set -e

# To test an evaluator with a different name, pass it as the first argument.
exe="evaluator"
if test -n "$1" ; then
    exe="$1"
fi

tempout=$( mktemp )
tempdiff=$( mktemp )

for f in tests/test*.json ; do
    base=$( basename $f .json )
    echo "👉 $base"
    set +e
    cat $f | ./$exe > $tempout 2>&1
    status=$?
    set -e
    if test -e tests/${base}.out ; then
        if diff -urN --color=always $tempout tests/${base}.out > $tempdiff ; then
            echo "✅"
        else
            echo "❌ $base failed"
            echo "➡️  input:"
            cat tests/${base}.scm
            echo "➡️  output diff:"
            cat $tempdiff
            exit 1
        fi
    else
        if test $status -eq 0 ; then
            echo "✅ (output ignored)"
        else
            echo "❌ $base failed"
            echo "➡️  input:"
            cat tests/${base}.scm
            echo "➡️  output:"
            cat $tempout
            exit 2
        fi
    fi
done
