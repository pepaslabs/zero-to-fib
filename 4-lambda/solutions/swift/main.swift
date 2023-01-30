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
    case symbolNotFoundInEnvironment(_ symbol: Symbol)
    case cantEvaluateEmptyList
    case notCallable(_ value: LispValue)
    case missingIfStatementPredicate(_ list: [ASTNode])
    case missingIfStatementConsequent(_ list: [ASTNode])
    case missingIfStatementAlternative(_ list: [ASTNode])
    case missingLambdaParameterList(_ list: [ASTNode])
    case lambdaParametersMustBeAList(_ list: [ASTNode])
    case lambdaParametersMustBeSymbols(_ list: [ASTNode])
    case lambdaContainsNoStatements(_ list: [ASTNode])
    case insufficientArgumentsForLambda(_ args: [LispValue])
    case evaluationMustProduceValue(_ ast: ASTNode)
}


// MARK: - LispValue

typealias BuiltInLispFunction = ([LispValue]) throws -> (LispValue)

enum LispValue: CustomStringConvertible {
    case bool(_ value: Bool)
    case number(_ value: Double)
    case symbol(_ value: Symbol)
    case list(_ value: [ASTNode])
    case builtInFunction(_ fn: BuiltInLispFunction)
    case lambda(_ lamb: LispLambda)
    
    var description: String {
        switch self {
        case .bool(let value):
            return value ? "#t" : "#f"
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
        case .lambda(let lamb):
            return "#<lambda (\(lamb.params.joined(separator: " ")))>"
        }
    }
}

typealias Symbol = String

struct LispLambda {
    let params: [Symbol]
    let statements: [ASTNode]
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
    
    var symbol: Symbol? {
        return self["value"] as? Symbol
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
    for arg in args.dropFirst(1) {
        guard case .number(let value) = arg else {
            throw EvalutorError.badArgumentType(arg)
        }
        accumulator -= value
    }
    return .number(accumulator)
}

func lisp_lessThan(args: [LispValue]) throws -> LispValue {
    guard !args.isEmpty else {
        return .bool(true)
    }
    guard case .number(let firstArg) = args[0] else {
        throw EvalutorError.badArgumentType(args[0])
    }
    var prev: Double = firstArg
    for arg in args.dropFirst(1) {
        guard case .number(let value) = arg else {
            throw EvalutorError.badArgumentType(arg)
        }
        if !(prev < value) {
            return .bool(false)
        }
        prev = value
        continue
    }
    return .bool(true)
}


// MARK: - Evaluator

func lookup(symbol: Symbol, env: Environment) throws -> LispValue {
    if let value = env.values[symbol] {
        return value
    } else if let parent_env = env.parent {
        return try lookup(symbol: symbol, env: parent_env)
    } else {
        throw EvalutorError.symbolNotFoundInEnvironment(symbol)
    }
}

func is_truthy(value: LispValue) -> Bool {
    if case .bool(let b) = value, b == false {
        return false
    } else {
        return true
    }
}

func lisp_eval(ast: ASTNode, env: Environment) throws -> LispValue? {
    if let value = ast.number {
        return .number(value)

    } else if let symbol = ast.symbol {
        return try lookup(symbol: symbol, env: env)

    } else if let list = ast.list {
        if list.isEmpty {
            throw EvalutorError.cantEvaluateEmptyList
        }

        // This is an "if" statement.
        if list[0].symbol == "if" {
            if list.count < 2 {
                throw EvalutorError.missingIfStatementPredicate(list)
            }
            guard let predicate = try lisp_eval(ast: list[1], env: env) else {
                throw EvalutorError.evaluationMustProduceValue(list[1])
            }
            if is_truthy(value: predicate) {
                if list.count < 3 {
                    throw EvalutorError.missingIfStatementConsequent(list)
                }
                let consequent = try lisp_eval(ast: list[2], env: env)
                return consequent
            } else {
                if list.count < 4 {
                    throw EvalutorError.missingIfStatementAlternative(list)
                }
                let alternative = try lisp_eval(ast: list[3], env: env)
                return alternative
            }
            
        // This is a "lambda" statement.
        } else if list[0].symbol == "lambda" {
            if list.count < 2 {
                throw EvalutorError.missingLambdaParameterList(list)
            }
            guard let param_list = list[1].list else {
                throw EvalutorError.lambdaParametersMustBeAList(list)
            }
            let params = try param_list.map({
                guard let symbol = $0.symbol else {
                    throw EvalutorError.lambdaParametersMustBeSymbols(list)
                }
                return symbol
            })
            if list.count < 3 {
                throw EvalutorError.lambdaContainsNoStatements(list)
            }
            let statements = Array(list.dropFirst(2))
            return .lambda(
                LispLambda(params: params, statements: statements)
            )

        // This is a normal function application.
        } else {
            guard let operator_ = try lisp_eval(ast: list[0], env: env) else {
                throw EvalutorError.evaluationMustProduceValue(list[0])
            }
            let operands = try list.dropFirst(1).map({
                guard let operand = try lisp_eval(ast: $0, env: env) else {
                    throw EvalutorError.evaluationMustProduceValue($0)
                }
                return operand
            })
            return try lisp_apply(operator_: operator_, operands: operands, env: env)
        }

    } else {
        throw EvalutorError.unableToEvaluateASTNode(ast)
    }
}

func lisp_apply(operator_: LispValue, operands: [LispValue], env: Environment) throws -> LispValue? {
    if case .builtInFunction(let fn) = operator_ {
        return try fn(operands)
    } else if case .lambda(let lamb) = operator_ {
        let local_env = Environment(values: [:], parent: env)
        for (i, param) in lamb.params.enumerated() {
            guard let operand = operands.get(at: i) else {
                throw EvalutorError.insufficientArgumentsForLambda(operands)
            }
            local_env.values[param] = operand
        }
        var lastStatementValue: LispValue? = nil
        for statement in lamb.statements {
            lastStatementValue = try lisp_eval(ast: statement, env: local_env)
        }
        return lastStatementValue
    } else {
        throw EvalutorError.notCallable(operator_)
    }
}


// MARK: - Environment

class Environment {
    var values: Dictionary<String,LispValue>
    var parent: Environment?

    init(values: Dictionary<String, LispValue>, parent: Environment? = nil) {
        self.parent = parent
        self.values = values
    }
}

let g_env: Environment = .init(
    values: [
        "#t": .bool(true),
        "#f": .bool(false),
        "pi": .number(3.14159),
        "+": .builtInFunction(lisp_plus(args:)),
        "-": .builtInFunction(lisp_minus(args:)),
        "<": .builtInFunction(lisp_lessThan(args:)),
    ]
)


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


// MARK: - Array

extension Array {
    func get(at index: Int) -> Element? {
        if count <= index {
            return nil
        } else {
            return self[index]
        }
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
        if let value = try lisp_eval(ast: ast, env: g_env) {
            print(value)
        }
    }
}
try main()
