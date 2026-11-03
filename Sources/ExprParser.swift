import Foundation

struct ExprError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

indirect enum ExprNode {
    case constant(Double)
    case variable
    case negate(ExprNode)
    case add(ExprNode, ExprNode)
    case subtract(ExprNode, ExprNode)
    case multiply(ExprNode, ExprNode)
    case divide(ExprNode, ExprNode)
    case power(ExprNode, ExprNode)
    case call(String, ExprNode)

    func evaluate(_ x: Double) -> Double {
        switch self {
        case .constant(let value): return value
        case .variable: return x
        case .negate(let a): return -a.evaluate(x)
        case .add(let a, let b): return a.evaluate(x) + b.evaluate(x)
        case .subtract(let a, let b): return a.evaluate(x) - b.evaluate(x)
        case .multiply(let a, let b): return a.evaluate(x) * b.evaluate(x)
        case .divide(let a, let b): return a.evaluate(x) / b.evaluate(x)
        case .power(let a, let b): return Foundation.pow(a.evaluate(x), b.evaluate(x))
        case .call(let name, let arg):
            guard let fn = ExprNode.functions[name] else { return .nan }
            return fn(arg.evaluate(x))
        }
    }

    static let functions: [String: (Double) -> Double] = [
        "sin": { sin($0) },
        "cos": { cos($0) },
        "tan": { tan($0) },
        "cot": { 1 / tan($0) },
        "sec": { 1 / cos($0) },
        "csc": { 1 / sin($0) },
        "cosec": { 1 / sin($0) },
        "asin": { asin($0) },
        "acos": { acos($0) },
        "atan": { atan($0) },
        "arcsin": { asin($0) },
        "arccos": { acos($0) },
        "arctan": { atan($0) },
        "sinh": { sinh($0) },
        "cosh": { cosh($0) },
        "tanh": { tanh($0) },
        "coth": { 1 / tanh($0) },
        "sech": { 1 / cosh($0) },
        "csch": { 1 / sinh($0) },
        "ln": { log($0) },
        "log": { log10($0) },
        "lg": { log10($0) },
        "log10": { log10($0) },
        "log2": { log2($0) },
        "sqrt": { sqrt($0) },
        "abs": { Swift.abs($0) },
        "exp": { exp($0) },
        "floor": { floor($0) },
        "ceil": { ceil($0) },
        "round": { $0.rounded() },
        "sign": { $0 > 0 ? 1 : ($0 < 0 ? -1 : 0) },
        "gamma": { tgamma($0) }
    ]
}

struct Expr {
    let root: ExprNode

    func eval(_ x: Double) -> Double { root.evaluate(x) }

    static func parse(_ text: String) throws -> Expr {
        var parser = try Parser(text)
        let node = try parser.parseExpression()
        guard parser.atEnd else { throw ExprError("表达式有多余内容") }
        return Expr(root: node)
    }
}

private struct Parser {
    private enum Token: Equatable {
        case number(Double)
        case name(String)
        case symbol(Character)
    }

    private var tokens: [Token]
    private var index = 0

    init(_ text: String) throws {
        tokens = try Parser.tokenize(text)
        if tokens.isEmpty { throw ExprError("表达式为空") }
    }

    var atEnd: Bool { index >= tokens.count }

    // MARK: - 词法

    private static func tokenize(_ text: String) throws -> [Token] {
        var out: [Token] = []
        var i = text.startIndex

        while i < text.endIndex {
            let c = text[i]

            if c == " " || c == "\t" || c == "\n" {
                i = text.index(after: i)
                continue
            }

            if c.isNumber || c == "." {
                var literal = ""
                while i < text.endIndex, text[i].isNumber || text[i] == "." {
                    literal.append(text[i])
                    i = text.index(after: i)
                }
                // 科学计数法 1e-3
                if i < text.endIndex, text[i] == "e" || text[i] == "E" {
                    var j = text.index(after: i)
                    var tail = "e"
                    if j < text.endIndex, text[j] == "+" || text[j] == "-" {
                        tail.append(text[j])
                        j = text.index(after: j)
                    }
                    var digits = ""
                    while j < text.endIndex, text[j].isNumber {
                        digits.append(text[j])
                        j = text.index(after: j)
                    }
                    if !digits.isEmpty {
                        tail += digits
                        literal += tail
                        i = j
                    }
                }
                guard let value = Double(literal) else { throw ExprError("数字格式不正确") }
                out.append(.number(value))
                continue
            }

            if c.isLetter || c == "π" {
                var name = ""
                while i < text.endIndex, text[i].isLetter || text[i] == "π" {
                    name.append(text[i])
                    i = text.index(after: i)
                }
                out.append(.name(name.lowercased()))
                continue
            }

            switch c {
            case "+", "-", "*", "/", "^", "(", ")", ",":
                out.append(.symbol(c))
            case "×", "·":
                out.append(.symbol("*"))
            case "÷":
                out.append(.symbol("/"))
            case "−":
                out.append(.symbol("-"))
            case "（":
                out.append(.symbol("("))
            case "）":
                out.append(.symbol(")"))
            default:
                throw ExprError("无法识别的字符「\(c)」")
            }
            i = text.index(after: i)
        }
        return out
    }

    // MARK: - 语法

    private func peek() -> Token? {
        index < tokens.count ? tokens[index] : nil
    }

    private mutating func advance() { index += 1 }

    private func isSymbol(_ c: Character) -> Bool {
        peek() == .symbol(c)
    }

    private func startsPrimary() -> Bool {
        guard let token = peek() else { return false }
        switch token {
        case .number, .name: return true
        case .symbol(let c): return c == "("
        }
    }

    mutating func parseExpression() throws -> ExprNode {
        var node = try parseTerm()
        while let token = peek() {
            if token == .symbol("+") {
                advance()
                node = .add(node, try parseTerm())
            } else if token == .symbol("-") {
                advance()
                node = .subtract(node, try parseTerm())
            } else {
                break
            }
        }
        return node
    }

    private mutating func parseTerm() throws -> ExprNode {
        var node = try parseUnary()
        while true {
            if isSymbol("*") {
                advance()
                node = .multiply(node, try parseUnary())
            } else if isSymbol("/") {
                advance()
                node = .divide(node, try parseUnary())
            } else if startsPrimary() {
                // 省略乘号: 2x / 3(x+1) / (x+1)(x-1) / 2sin(x)
                node = .multiply(node, try parseUnary())
            } else {
                break
            }
        }
        return node
    }

    private mutating func parseUnary() throws -> ExprNode {
        if isSymbol("-") {
            advance()
            return .negate(try parseUnary())
        }
        if isSymbol("+") {
            advance()
            return try parseUnary()
        }
        return try parsePower()
    }

    private mutating func parsePower() throws -> ExprNode {
        let base = try parsePrimary()
        if isSymbol("^") {
            advance()
            let exponent = try parseUnary()   // 右结合, 支持 2^-1
            return .power(base, exponent)
        }
        return base
    }

    private mutating func parsePrimary() throws -> ExprNode {
        guard let token = peek() else { throw ExprError("表达式不完整") }

        switch token {
        case .number(let value):
            advance()
            return .constant(value)

        case .name(var name):
            advance()
            if name == "π" { name = "pi" }

            if isSymbol("(") {
                advance()
                let arg = try parseExpression()
                guard isSymbol(")") else { throw ExprError("缺少右括号") }
                advance()
                guard ExprNode.functions[name] != nil else {
                    throw ExprError("未知函数 \(name)")
                }
                return .call(name, arg)
            }

            switch name {
            case "x": return .variable
            case "pi": return .constant(Double.pi)
            case "e": return .constant(2.718281828459045)
            default: throw ExprError("未知符号 \(name)")
            }

        case .symbol(let c) where c == "(":
            advance()
            let inner = try parseExpression()
            guard isSymbol(")") else { throw ExprError("缺少右括号") }
            advance()
            return inner

        default:
            throw ExprError("这里缺少操作数")
        }
    }
}
