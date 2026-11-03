import SwiftUI
import Foundation

struct PlotCanvas: View {
    @ObservedObject var viewport: Viewport
    @EnvironmentObject private var model: PlotModel

    var exportMode: Bool = false

    @State private var panBase: Viewport.Snapshot?
    @State private var zoomBase: Viewport.Snapshot?

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                draw(context: &context, size: size)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(size: geo.size))
            .simultaneousGesture(zoomGesture())
            .onTapGesture(count: 2) {
                guard !exportMode else { return }
                model.resetViewport()
            }
        }
    }

    // MARK: - 手势

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard !exportMode else { return }
                if panBase == nil { panBase = viewport.snapshot }
                guard let base = panBase, size.width > 1, size.height > 1 else { return }

                let spanX = base.x1 - base.x0
                let spanY = base.y1 - base.y0
                let dx = -Double(value.translation.width) / Double(size.width) * spanX
                let dy = Double(value.translation.height) / Double(size.height) * spanY

                viewport.set(x0: base.x0 + dx, x1: base.x1 + dx,
                             y0: base.y0 + dy, y1: base.y1 + dy)
            }
            .onEnded { _ in panBase = nil }
    }

    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                guard !exportMode else { return }
                if zoomBase == nil { zoomBase = viewport.snapshot }
                guard let base = zoomBase else { return }

                let factor = max(0.05, Double(scale))
                let centerX = (base.x0 + base.x1) / 2
                let centerY = (base.y0 + base.y1) / 2
                let spanX = (base.x1 - base.x0) / factor
                let spanY = (base.y1 - base.y0) / factor

                viewport.set(x0: centerX - spanX / 2, x1: centerX + spanX / 2,
                             y0: centerY - spanY / 2, y1: centerY + spanY / 2)
            }
            .onEnded { _ in zoomBase = nil }
    }

    // MARK: - 绘制

    private func draw(context: inout GraphicsContext, size: CGSize) {
        let width = size.width
        let height = size.height
        guard width > 2, height > 2 else { return }

        let spanX = viewport.x1 - viewport.x0
        let spanY = viewport.y1 - viewport.y0
        guard spanX > 0, spanY > 0 else { return }

        func px(_ x: Double) -> CGFloat {
            CGFloat((x - viewport.x0) / spanX * Double(width))
        }
        func py(_ y: Double) -> CGFloat {
            CGFloat(Double(height) - (y - viewport.y0) / spanY * Double(height))
        }

        if model.showGrid {
            drawGrid(context: &context, size: size, px: px, py: py)
        }
        drawAxes(context: &context, size: size, px: px, py: py)

        for item in model.functions where item.isVisible {
            guard let expr = item.expr else { continue }
            let color = PlotModel.palette[item.colorIndex % PlotModel.palette.count]
            let path = curvePath(expr: expr, size: size)
            if !path.isEmpty {
                context.stroke(path,
                               with: .color(color.opacity(0.22)),
                               style: StrokeStyle(lineWidth: CGFloat(model.lineWidth) * 3.2,
                                                  lineCap: .round, lineJoin: .round))
                context.stroke(path,
                               with: .color(color),
                               style: StrokeStyle(lineWidth: CGFloat(model.lineWidth),
                                                  lineCap: .round, lineJoin: .round))
            }
        }

        if model.showLegend {
            drawLegend(context: &context, size: size)
        }
    }

    private func drawGrid(context: inout GraphicsContext,
                          size: CGSize,
                          px: (Double) -> CGFloat,
                          py: (Double) -> CGFloat) {
        let stepX = niceStep(viewport.x1 - viewport.x0, target: 7)
        let stepY = niceStep(viewport.y1 - viewport.y0, target: 7)
        let color = Color.primary.opacity(0.075)

        var path = Path()

        if stepX > 0 {
            var x = (viewport.x0 / stepX).rounded(.up) * stepX
            var guardCount = 0
            while x <= viewport.x1, guardCount < 400 {
                let sx = px(x)
                path.move(to: CGPoint(x: sx, y: 0))
                path.addLine(to: CGPoint(x: sx, y: size.height))
                x += stepX
                guardCount += 1
            }
        }

        if stepY > 0 {
            var y = (viewport.y0 / stepY).rounded(.up) * stepY
            var guardCount = 0
            while y <= viewport.y1, guardCount < 400 {
                let sy = py(y)
                path.move(to: CGPoint(x: 0, y: sy))
                path.addLine(to: CGPoint(x: size.width, y: sy))
                y += stepY
                guardCount += 1
            }
        }

        context.stroke(path, with: .color(color), lineWidth: 0.8)
    }

    private func drawAxes(context: inout GraphicsContext,
                          size: CGSize,
                          px: (Double) -> CGFloat,
                          py: (Double) -> CGFloat) {
        var axis = Path()
        let color = Color.primary.opacity(0.32)

        if viewport.y0 <= 0 && viewport.y1 >= 0 {
            let sy = py(0)
            axis.move(to: CGPoint(x: 0, y: sy))
            axis.addLine(to: CGPoint(x: size.width, y: sy))
        }
        if viewport.x0 <= 0 && viewport.x1 >= 0 {
            let sx = px(0)
            axis.move(to: CGPoint(x: sx, y: 0))
            axis.addLine(to: CGPoint(x: sx, y: size.height))
        }

        context.stroke(axis, with: .color(color), lineWidth: 1.1)
    }

    private func curvePath(expr: Expr, size: CGSize) -> Path {
        let points = max(240, min(model.sampleCount, 6000))
        let spanX = viewport.x1 - viewport.x0
        let spanY = viewport.y1 - viewport.y0
        var path = Path()

        var hasPrevious = false
        var previousY = 0.0

        for i in 0...points {
            let t = Double(i) / Double(points)
            let x = viewport.x0 + spanX * t
            let y = expr.eval(x)

            let isValid = y.isFinite && abs(y) < 1e9
            if !isValid {
                hasPrevious = false
                continue
            }

            let sx = CGFloat(t) * size.width
            let sy = CGFloat(Double(size.height) - (y - viewport.y0) / spanY * Double(size.height))

            let jumped = hasPrevious && abs(y - previousY) > spanY * 6
            if !hasPrevious || (model.breakPoles && jumped) {
                path.move(to: CGPoint(x: sx, y: sy))
            } else {
                path.addLine(to: CGPoint(x: sx, y: sy))
            }

            previousY = y
            hasPrevious = true
        }

        return path
    }

    private func drawLegend(context: inout GraphicsContext, size: CGSize) {
        let visible = model.functions.filter { $0.isVisible && $0.expr != nil }
        guard !visible.isEmpty else { return }

        var top = 12.0
        for item in visible.prefix(8) {
            let color = PlotModel.palette[item.colorIndex % PlotModel.palette.count]
            let label = Text("y = " + item.displayText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(color)
            context.draw(label, at: CGPoint(x: size.width - 12, y: top), anchor: .topTrailing)
            top += 16
        }
    }

    private func niceStep(_ span: Double, target: Int) -> Double {
        guard span > 0, span.isFinite else { return 1 }
        let raw = span / Double(target)
        let magnitude = Foundation.pow(10, Foundation.floor(Foundation.log10(raw)))
        let normalized = raw / magnitude
        let step: Double
        if normalized <= 1 {
            step = 1
        } else if normalized <= 2 {
            step = 2
        } else if normalized <= 5 {
            step = 5
        } else {
            step = 10
        }
        return step * magnitude
    }
}
