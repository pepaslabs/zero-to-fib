#!/usr/bin/env python3

import sys
import json


def lisp_eval(ast):
    if ast["type"] == "number":
        return ast["value"]
    else:
        raise Exception("Don't know how to evaluate %s" % ast)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        input = open(sys.argv[-1]).read()
    else:
        input = sys.stdin.read()
    asts = json.loads(input)
    for ast in asts:
        value = lisp_eval(ast)
        print(value)
