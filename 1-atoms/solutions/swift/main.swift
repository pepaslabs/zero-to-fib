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
}


// MARK: - LispValue

enum LispValue: CustomStringConvertible {
    case number(_ value: Double)
    
    var description: String {
        switch self {
        case .number(let value):
            // drop any superfluous fractional portion when printing.
            if Double(Int(value)) == value {
                return "\(Int(value))"
            } else {
                return "\(value)"
            }
        }
    }
}


// MARK: - AST

typealias ASTNode = Dictionary<String,Any>

enum ASTType: String {
    case number
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
}


// MARK: - Evaluator

func lisp_eval(ast: ASTNode) throws -> LispValue {
    if let value = ast.number {
        return .number(value)
    } else {
        throw EvalutorError.unableToEvaluateASTNode(ast)
    }
}


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
        let value = try lisp_eval(ast: ast)
        print(value)
    }
}
try main()
