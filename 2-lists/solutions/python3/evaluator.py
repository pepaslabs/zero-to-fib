#!/usr/bin/env python3

import sys
import json


def lisp_plus(args):
    accum = 0
    for arg in args:
        accum += arg
    return accum


def lisp_minus(args):
    if len(args) == 0:
        return 0
    accum = args[0]
    for arg in args[1:]:
        accum -= arg
    return accum


g_env = {
    "pi": 3.14159,
    "+": lisp_plus,
    "-": lisp_minus
}


def lisp_eval(ast):
    if ast["type"] == "number":
        return ast["value"]
    elif ast["type"] == "symbol":
        symbol = ast["value"]
        return g_env[symbol]
    elif ast["type"] == "list":
        items = ast["value"]
        if len(items) == 0:
            raise Exception("Can't evaluate zero-length list.")
        operator = lisp_eval(items[0])
        operands = list(map(lambda x: lisp_eval(x), items[1:]))
        return lisp_apply(operator, operands)
    else:
        raise Exception("Don't know how to evaluate %s" % ast)


def lisp_apply(operator, operands):
    return operator(operands)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        input = open(sys.argv[-1]).read()
    else:
        input = sys.stdin.read()
    asts = json.loads(input)
    for ast in asts:
        value = lisp_eval(ast)
        print(value)
