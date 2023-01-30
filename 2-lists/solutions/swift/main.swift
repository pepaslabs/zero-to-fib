//
//  main.swift
//  evaluator
//
//  Created by jason.pepas on 1/28/23.
//

import Foundation


// MARK: - Errors

enum EvalutorError: Error {
    case badJSON
    case unableToEvaluateASTNode(_ node: ASTNode)
    case notImplemented
    case badArgumentType(_ value: LispValue)
    case symbolNotFoundInEnvironment(_ symbol: String)
    case cantEvaluateEmptyList
    case notCallable(_ value: LispValue)
}


// MARK: - LispValue

typealias BuiltInLispFunction = ([LispValue]) throws -> (LispValue)

enum LispValue: CustomStringConvertible {
    case number(_ value: Double)
    case symbol(_ value: String)
    case list(_ value: [ASTNode])
    case builtInFunction(_ fn: BuiltInLispFunction)
    
    var description: String {
        switch self {
        case .number(let value):
            // drop any superfluous fractional portion when printing.
            if Double(Int(value)) == value {
                return "\(Int(value))"
            } else {
                return "\(value)"
            }
        case .symbol(let value):
            return value
        case .list(let value):
            return "(\(value))"
        case .builtInFunction(let fn):
            return String(describing: fn)
        }
    }
}


// MARK: - AST

typealias ASTNode = Dictionary<String,Any>

enum ASTType: String {
    case number
    case symbol
    case list
}

extension Dictionary where Key == String, Value == Any {
    var type: ASTType {
        get throws {
            guard let typeStr = self["type"] as? String,
                  let typeEnum = ASTType(rawValue: typeStr)
            else {
                throw EvalutorError.badJSON
            }
            return typeEnum
        }
    }
    
    var number: Double? {
        return self["value"] as? Double
    }
    
    var symbol: String? {
        return self["value"] as? String
    }
    
    var list: [ASTNode]? {
        return self["value"] as? [ASTNode]
    }
}


// MARK: - Built-in Lisp functions

func lisp_plus(args: [LispValue]) throws -> LispValue {
    var accumulator: Double = 0
    try args.forEach { arg in
        guard case .number(let value) = arg else {
            throw EvalutorError.badArgumentType(arg)
        }
        accumulator += value
    }
    return .number(accumulator)
}


func lisp_minus(args: [LispValue]) throws -> LispValue {
    guard !args.isEmpty else {
        return .number(0)
    }
    guard case .number(let firstArg) = args[0] else {
        throw EvalutorError.badArgumentType(args[0])
    }
    var accumulator: Double = firstArg
    try args.dropFirst(1).forEach { arg in
        guard case .number(let value) = arg else {
            throw EvalutorError.badArgumentType(arg)
        }
        accumulator -= value
    }
    return .number(accumulator)
}


// MARK: - Evaluator

func lookup(symbol: String, env: Environment) throws -> LispValue {
    guard let value = env[symbol] else {
        throw EvalutorError.symbolNotFoundInEnvironment(symbol)
    }
    return value
}

func lisp_eval(ast: ASTNode, env: Environment) throws -> LispValue {
    if let value = ast.number {
        return .number(value)
    } else if let symbol = ast.symbol {
        return try lookup(symbol: symbol, env: env)
    } else if let list = ast.list {
        if list.isEmpty {
            throw EvalutorError.cantEvaluateEmptyList
        }
        let operator_ = try lisp_eval(ast: list[0], env: env)
        let operands = try list.dropFirst(1).map({ try lisp_eval(ast: $0, env: env) })
        return try lisp_apply(operator_: operator_, operands: operands)
    } else {
        throw EvalutorError.unableToEvaluateASTNode(ast)
    }
}

func lisp_apply(operator_: LispValue, operands: [LispValue]) throws -> LispValue {
    guard case .builtInFunction(let fn) = operator_ else {
        throw EvalutorError.notCallable(operator_)
    }
    return try fn(operands)
}


// MARK: - Environment

typealias Environment = Dictionary<String,LispValue>

let g_env: Environment = [
    "pi": .number(3.14159),
    "+": .builtInFunction(lisp_plus(args:)),
    "-": .builtInFunction(lisp_minus(args:)),
]


// MARK: - Input

func readStdin() -> Data? {
    guard let firstLine = readLine(strippingNewline: false) else {
        return nil
    }
    var content = firstLine
    while(true) {
        if let line = readLine(strippingNewline: false) {
            content += line
        } else {
            break
        }
    }
    return content.data(using: .utf8)
}

func readFile(path: String) throws -> Data {
    let url: URL
    if #available(macOS 13.0, *) {
        url = URL(filePath: FileManager.default.currentDirectoryPath).appending(component: path)
    } else {
        url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(path)
    }
    return try Data(contentsOf: url)
}

func getInput() throws -> Data? {
    if CommandLine.arguments.count > 1 {
        let fname = CommandLine.arguments[1]
        return try readFile(path: fname)
    } else {
        return readStdin()
    }
}


// MARK: - main

func main() throws {
    guard let data = try getInput() else {
        exit(1)
    }
    let asts = try JSONSerialization.jsonObject(with: data)
    guard let asts = asts as? [ASTNode] else {
        throw EvalutorError.badJSON
    }
    try asts.forEach { ast in
        let value = try lisp_eval(ast: ast, env: g_env)
        print(value)
    }
}
try main()
