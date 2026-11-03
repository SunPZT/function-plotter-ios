import SwiftUI
import Foundation

/// OSNB 彩蛋: 画布上放烟花 + 中央弹出大字
struct FireworksOverlay: View {
    private let started = Date()

    private struct Burst {
        let time: Double
        let x: Double
        let y: Double
        let hue: Double
        let count: Int
    }

    private static let bursts: [Burst] = [
        Burst(time: 0.30, x: 0.28, y: 0.40, hue: 0.58, count: 58),
        Burst(time: 0.72, x: 0.70, y: 0.33, hue: 0.92, count: 54),
        Burst(time: 1.15, x: 0.50, y: 0.52, hue: 0.13, count: 66),
        Burst(time: 1.62, x: 0.22, y: 0.30, hue: 0.45, count: 50),
        Burst(time: 2.04, x: 0.78, y: 0.45, hue: 0.78, count: 54)
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(started)
                for burst in FireworksOverlay.bursts {
                    draw(burst: burst, elapsed: elapsed, context: &context, size: size)
                }
            }
        }
        .overlay(
            Text("开 源 牛 逼 ✦")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.32, green: 0.58, blue: 1.0),
                                 Color(red: 0.98, green: 0.42, blue: 0.72),
                                 Color(red: 1.0, green: 0.72, blue: 0.30)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .white.opacity(0.85), radius: 14)
                .modifier(PopInModifier())
        )
        .allowsHitTesting(false)
    }

    private func draw(burst: Burst,
                      elapsed: Double,
                      context: inout GraphicsContext,
                      size: CGSize) {
        // 升空
        let launchTime = burst.time - 0.55
        if elapsed >= launchTime, elapsed < burst.time {
            let t = (elapsed - launchTime) / 0.55
            let y = size.height * (burst.y + 0.35) - (size.height * 0.35) * t
            let x = size.width * burst.x + sin(t * 6) * 3
            let color = Color(hue: burst.hue, saturation: 0.5, brightness: 1)
            context.fill(
                Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)),
                with: .color(color.opacity(0.9))
            )
            context.fill(
                Path(ellipseIn: CGRect(x: x - 7, y: y - 7, width: 14, height: 14)),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.35), color.opacity(0)]),
                    center: CGPoint(x: x, y: y),
                    startRadius: 0,
                    endRadius: 7
                )
            )
            return
        }

        let dt = elapsed - burst.time
        guard dt >= 0, dt < 2.2 else { return }

        let center = CGPoint(x: size.width * burst.x, y: size.height * burst.y)
        let drag = 2.1

        for i in 0..<burst.count {
            let seed = Double(i) * 12.9898 + burst.hue * 78.233
            let r1 = abs(sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1)
            let r2 = abs(sin(seed * 1.71) * 24634.6345).truncatingRemainder(dividingBy: 1)

            let angle = r1 * Double.pi * 2
            let speed = 60 + r2 * 190
            let decay = (1 - exp(-drag * dt)) / drag
            let x = center.x + CGFloat(cos(angle) * speed * decay)
            let y = center.y + CGFloat(sin(angle) * speed * decay + 46 * dt * dt)

            let life = max(0, 1 - dt / 1.75)
            guard life > 0 else { continue }
            let alpha = pow(life, 1.35)
            let radius = CGFloat(1.4 + r1 * 1.6)
            let color = Color(hue: (burst.hue + r1 * 0.10).truncatingRemainder(dividingBy: 1),
                              saturation: 0.85,
                              brightness: 1)

            context.fill(
                Path(ellipseIn: CGRect(x: x - radius * 3, y: y - radius * 3,
                                       width: radius * 6, height: radius * 6)),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(alpha * 0.30), color.opacity(0)]),
                    center: CGPoint(x: x, y: y),
                    startRadius: 0,
                    endRadius: radius * 3
                )
            )
            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                       width: radius * 2, height: radius * 2)),
                with: .color(color.opacity(alpha))
            )
        }
    }
}

private struct PopInModifier: ViewModifier {
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown ? 1 : 0.35)
            .opacity(shown ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                    shown = true
                }
            }
    }
}
