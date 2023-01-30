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


def lookup(symbol, env):
    if symbol in env:
        return env[symbol]
    elif "__parent_env__" in env:
        return lookup(symbol, env["__parent_env__"])
    else:
        raise Exception("Symbol '%s' not found." % symbol)


def is_truthy(value):
    return not (isinstance(value, bool) and value == False)


class LispLambda:
    def __init__(self, params, statements):
        self.params = params
        self.statements = statements


def is_lambda(value):
    return isinstance(value, LispLambda)


def lisp_eval(ast, env):
    if ast["type"] == "number":
        return ast["value"]
    elif ast["type"] == "symbol":
        symbol = ast["value"]
        return lookup(symbol, env)
    elif ast["type"] == "list":
        items = ast["value"]
        if len(items) == 0:
            raise Exception("Can't evaluate zero-length list.")
        ast0 = items[0]

        # this list is an 'if' statement.
        if ast0["value"] == "if":
            if len(items) < 2:
                raise Exception("Missing predicate for 'if' statement.")
            predicate = lisp_eval(items[1], env)
            if is_truthy(predicate):
                if len(items) < 3:
                    raise Exception("Missing consequent for 'if' statement.")
                consequent = lisp_eval(items[2], env)
                return consequent
            else:
                if len(items) < 4:
                    raise Exception("Missing alternative for 'if' statement.")
                alternative = lisp_eval(items[3], env)
                return alternative

        # this list is a 'lambda' statement.
        if ast0["value"] == "lambda":
            if len(items) < 2:
                raise Exception("Missing parameter list for 'lambda' statement.")
            params_ast = items[1]
            if params_ast["type"] != "list":
                raise Exception("'lambda' arguments must be a list.")
            if len(items) < 3:
                raise Exception("'lambda' body contains no statements.")
            statement_asts = items[2:]
            return LispLambda(params_ast, statement_asts)

        # this list is a normal function application.
        else:
            operator_ast = items[0]
            operator = lisp_eval(operator_ast, env)
            operand_asts = items[1:]
            operands = list(map(lambda operand_ast: lisp_eval(operand_ast, env), operand_asts))
            return lisp_apply(operator, operands, env)

    else:
        raise Exception("Don't know how to evaluate %s" % ast)


def lisp_apply(operator, operands, env):
    if is_lambda(operator):
        lamb = operator
        local_env = { "__parent_env__": env }
        lambda_params_ast = lamb.params
        lambda_params = lambda_params_ast["value"]
        for i in range(len(lambda_params)):
            symbol_ast = lambda_params[i]
            symbol = symbol_ast["value"]
            if len(operands) <= i:
                raise Exception("Insufficient args for lambda.")
            arg = operands[i]
            local_env[symbol] = arg
        # evaluate each of the lambda statements and return the last value.
        value = None
        for statement_ast in lamb.statements:
            value = lisp_eval(statement_ast, local_env)
        return value
    else:
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
    elif is_lambda(value):
        s = "#<lambda ("
        lamb = value
        lambda_params_ast = lamb.params
        lambda_param_asts = lambda_params_ast["value"]
        params = map(lambda param_ast: param_ast["value"], lambda_param_asts)
        s += " ".join(params)
        s += ")>"
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
        value = lisp_eval(ast, g_env)
        sys.stdout.write(lisp_print(value) + "\n")
