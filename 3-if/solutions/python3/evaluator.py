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


def lisp_lessthan(args):
    if len(args) == 0:
        return True
    prev = args[0]
    for arg in args[1:]:
        if not (prev < arg):
            return False
        prev = arg
        continue
    return True


g_env = {
    "#t": True,
    "#f": False,
    "pi": 3.14159,
    "+": lisp_plus,
    "-": lisp_minus,
    "<": lisp_lessthan
}


def is_truthy(value):
    return not (isinstance(value, bool) and value == False)


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
        ast0 = items[0]

        # this list is an 'if' statement.
        if ast0["value"] == "if":
            if len(items) < 2:
                raise Exception("Missing predicate for 'if' statement")
            predicate = lisp_eval(items[1])
            if is_truthy(predicate):
                if len(items) < 3:
                    raise Exception("Missing consequent for 'if' statement")
                consequent = lisp_eval(items[2])
                return consequent
            else:
                if len(items) < 4:
                    raise Exception("Missing alternative for 'if' statement")
                alternative = lisp_eval(items[3])
                return alternative

        # this list is a normal function application.
        else:
            operator_ast = items[0]
            operator = lisp_eval(operator_ast)
            operand_asts = items[1:]
            operands = list(map(lambda operand_ast: lisp_eval(operand_ast), operand_asts))
            return lisp_apply(operator, operands)
    else:
        raise Exception("Don't know how to evaluate %s" % ast)


def lisp_apply(operator, operands):
    return operator(operands)


def lisp_print(value):
    if isinstance(value, bool):
        if value:
            return "#t"
        else:
            return "#f"
    elif isinstance(value, list):
        s = "("
        for item in value:
            s += lisp_print(item)
        s += ")"
        return s
    else:
        return str(value)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        input = open(sys.argv[-1]).read()
    else:
        input = sys.stdin.read()
    asts = json.loads(input)
    for ast in asts:
        value = lisp_eval(ast)
        sys.stdout.write(lisp_print(value) + "\n")
