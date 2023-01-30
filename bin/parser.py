#!/usr/bin/env python3

# Parse a symbolic expression and print its JSON AST representation.
# Supports numbers, symbols, and lists (no string support).

import sys
import json
import re


def strip_comments(input):
    lines = input.splitlines()
    stripped_lines = map(lambda line: line.split(";")[0], lines)
    return "\n".join(stripped_lines)


def tokenize(input):
    return input.replace("(", " ( ").replace(")", " ) ").split()


def is_number(token):
    try:
        _ = int(token)
        return True
    except:
        try:
            _ = float(token)
            return True
        except:
            return False


def is_oparen(token):
    return token == "("


def is_cparen(token):
    return token == ")"


def behead(list):
    if len(list) == 0:
        return (None, [])
    else:
        return (list[0], list[1:])


def parse_number(tokens):
    failure = (None, tokens)
    (token, tokens) = behead(tokens)
    if token is None:
        return failure
    try:
        value = int(token)
    except:
        try:
            value = float(token)
        except:
            return failure
    ast = {"type": "number", "value": value}
    return (ast, tokens)


def parse_symbol(tokens):
    failure = (None, tokens)
    (token, tokens) = behead(tokens)
    if token is None:
        return failure
    if is_number(token) or is_oparen(token) or is_cparen(token):
        return failure
    ast = {"type": "symbol", "value": token}
    return (ast, tokens)


def parse_list(tokens):
    orig_tokens = tokens
    failure = (None, tokens)
    (token, tokens) = behead(tokens)
    if token is None:
        return failure
    if not is_oparen(token):
        return failure
    items = []
    while True:
        if len(tokens) == 0:
            raise Exception("Unterminated list: %s" % orig_tokens)
        if is_cparen(tokens[0]):
            ast = {"type": "list", "value": items}
            return (ast, tokens[1:])
        (ast, tokens) = parse_atom_or_list(tokens)
        if ast is not None:
            items.append(ast)
            continue
        # don't know what to do with this token.
        return failure


def parse_atom_or_list(tokens):
    failure = (None, tokens)
    (ast, tokens) = parse_list(tokens)
    if ast is not None:
        return (ast, tokens)
    (ast, tokens) = parse_number(tokens)
    if ast is not None:
        return (ast, tokens)
    (ast, tokens) = parse_symbol(tokens)
    if ast is not None:
        return (ast, tokens)
    return failure


if __name__ == "__main__":
    if len(sys.argv) > 1:
        input = open(sys.argv[-1]).read()
    else:
        input = sys.stdin.read()
    tokens = tokenize(strip_comments(input))
    asts = []
    while len(tokens) > 0:
        (ast, tokens) = parse_atom_or_list(tokens)
        if ast is None:
            raise Exception("Don't know how to parse %s" % tokens)
        asts.append(ast)
    if len(tokens) != 0:
        raise Exception("Leftover tokens: %s" % tokens)
    js = json.dumps(asts, sort_keys=True, indent=4)
    print(js)
