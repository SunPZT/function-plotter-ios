import SwiftUI
import Combine

struct PlotFunction: Identifiable {
    let id = UUID()
    var text: String
    var isVisible: Bool = true
    var expr: Expr? = nil
    var hasError: Bool = false
    var colorIndex: Int = 0

    var displayText: String {
        text.trimmingCharacters(in: .whitespaces).isEmpty ? "空" : text
    }
}

/// 视野单独一个对象: 拖拽缩放时只刷新画布, 不牵动整个界面
final class Viewport: ObservableObject {
    struct Snapshot {
        let x0: Double
        let x1: Double
        let y0: Double
        let y1: Double
    }

    private var minX = -10.0
    private var maxX = 10.0
    private var minY = -10.0
    private var maxY = 10.0

    var x0: Double { minX }
    var x1: Double { maxX }
    var y0: Double { minY }
    var y1: Double { maxY }

    var snapshot: Snapshot { Snapshot(x0: minX, x1: maxX, y0: minY, y1: maxY) }

    func set(x0: Double, x1: Double, y0: Double, y1: Double) {
        let x = Viewport.clamp(low: x0, high: x1)
        let y = Viewport.clamp(low: y0, high: y1)
        minX = x.0; maxX = x.1
        minY = y.0; maxY = y.1
        objectWillChange.send()
    }

    func reset() {
        minX = -10; maxX = 10
        minY = -10; maxY = 10
        objectWillChange.send()
    }

    private static func clamp(low: Double, high: Double) -> (Double, Double) {
        var a = low
        var b = high
        guard a.isFinite, b.isFinite, b > a else { return (a, b) }
        let minSpan = 1e-4
        let maxSpan = 1e7
        if b - a < minSpan {
            let center = (a + b) / 2
            a = center - minSpan / 2
            b = center + minSpan / 2
        }
        if b - a > maxSpan {
            let center = (a + b) / 2
            a = center - maxSpan / 2
            b = center + maxSpan / 2
        }
        return (a, b)
    }
}

final class PlotModel: ObservableObject {
    static let palette: [Color] = [
        Color(red: 0.22, green: 0.49, blue: 0.98),
        Color(red: 0.95, green: 0.32, blue: 0.52),
        Color(red: 0.11, green: 0.72, blue: 0.55),
        Color(red: 0.98, green: 0.58, blue: 0.13),
        Color(red: 0.60, green: 0.35, blue: 0.96),
        Color(red: 0.10, green: 0.65, blue: 0.86),
        Color(red: 0.88, green: 0.24, blue: 0.28),
        Color(red: 0.47, green: 0.58, blue: 0.12)
    ]

    let viewport = Viewport()

    @Published var functions: [PlotFunction] = [] {
        didSet { persist() }
    }
    @Published var sampleCount: Int = 1400 {
        didSet { persist() }
    }
    @Published var lineWidth: Double = 2.4 {
        didSet { persist() }
    }
    @Published var showGrid: Bool = true {
        didSet { persist() }
    }
    @Published var showLegend: Bool = true {
        didSet { persist() }
    }
    @Published var breakPoles: Bool = true {
        didSet { persist() }
    }
    @Published var animations: Bool = true {
        didSet { persist() }
    }
    @Published var eggToken: Int = 0

    private let defaults = UserDefaults.standard
    private var loading = false

    init() {
        load()
        if functions.isEmpty {
            addFunction(text: "sin(x)")
            addFunction(text: "0.12x^2 - 5")
        }
    }

    // MARK: - 增删改

    func addFunction(text: String = "") {
        let index = functions.count % PlotModel.palette.count
        var item = PlotFunction(text: text, colorIndex: index)
        if !text.trimmingCharacters(in: .whitespaces).isEmpty {
            item.expr = try? Expr.parse(stripPrefix(text))
            item.hasError = item.expr == nil
        }
        functions.append(item)
    }

    func remove(_ id: UUID) {
        functions.removeAll { $0.id == id }
    }

    func toggleVisible(_ id: UUID) {
        guard let index = functions.firstIndex(where: { $0.id == id }) else { return }
        functions[index].isVisible.toggle()
    }

    func setText(_ text: String, for id: UUID) {
        guard let index = functions.firstIndex(where: { $0.id == id }) else { return }

        if text.trimmingCharacters(in: .whitespaces).uppercased() == "OSNB" {
            functions[index].text = ""
            functions[index].expr = nil
            functions[index].hasError = false
            eggToken += 1
            return
        }

        functions[index].text = text
        recompile(index)
    }

    func function(_ id: UUID) -> PlotFunction? {
        functions.first { $0.id == id }
    }

    private func recompile(_ index: Int) {
        let raw = functions[index].text.trimmingCharacters(in: .whitespaces)
        if raw.isEmpty {
            functions[index].expr = nil
            functions[index].hasError = false
            return
        }
        do {
            functions[index].expr = try Expr.parse(stripPrefix(raw))
            functions[index].hasError = false
        } catch {
            functions[index].expr = nil
            functions[index].hasError = true
        }
    }

    private func stripPrefix(_ text: String) -> String {
        guard let range = text.range(of: "=") else { return text }
        let head = String(text[text.startIndex..<range.lowerBound])
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        if head == "y" || head == "f(x)" || head == "z" {
            return String(text[range.upperBound...])
        }
        return text
    }

    func resetViewport() {
        viewport.reset()
    }

    // MARK: - 持久化

    private func persist() {
        guard !loading else { return }
        defaults.set(functions.map { $0.text }, forKey: "fp.functionTexts")
        defaults.set(functions.map { $0.isVisible }, forKey: "fp.functionVisible")
        defaults.set(sampleCount, forKey: "fp.samples")
        defaults.set(lineWidth, forKey: "fp.lineWidth")
        defaults.set(showGrid, forKey: "fp.grid")
        defaults.set(showLegend, forKey: "fp.legend")
        defaults.set(breakPoles, forKey: "fp.breakPoles")
        defaults.set(animations, forKey: "fp.animations")
    }

    private func load() {
        loading = true
        defer { loading = false }

        if defaults.object(forKey: "fp.samples") != nil { sampleCount = defaults.integer(forKey: "fp.samples") }
        if defaults.object(forKey: "fp.lineWidth") != nil { lineWidth = defaults.double(forKey: "fp.lineWidth") }
        if defaults.object(forKey: "fp.grid") != nil { showGrid = defaults.bool(forKey: "fp.grid") }
        if defaults.object(forKey: "fp.legend") != nil { showLegend = defaults.bool(forKey: "fp.legend") }
        if defaults.object(forKey: "fp.breakPoles") != nil { breakPoles = defaults.bool(forKey: "fp.breakPoles") }
        if defaults.object(forKey: "fp.animations") != nil { animations = defaults.bool(forKey: "fp.animations") }

        guard let texts = defaults.array(forKey: "fp.functionTexts") as? [String] else { return }
        let visibles = defaults.array(forKey: "fp.functionVisible") as? [Bool] ?? []

        var restored: [PlotFunction] = []
        for (i, text) in texts.enumerated() {
            var item = PlotFunction(text: text, colorIndex: i % PlotModel.palette.count)
            item.isVisible = i < visibles.count ? visibles[i] : true
            if !text.trimmingCharacters(in: .whitespaces).isEmpty,
               let expr = try? Expr.parse(stripPrefix(text)) {
                item.expr = expr
            }
            restored.append(item)
        }
        functions = restored
    }
}
