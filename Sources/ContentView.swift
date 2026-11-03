import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: PlotModel

    @State private var showSettings = false
    @State private var showShare = false
    @State private var shareImage: UIImage?
    @State private var showEgg = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 10) {
                header
                plotCard
                equationPanel
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 10)

            if showEgg {
                FireworksOverlay()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .onChange(of: model.eggToken) { _ in
            withAnimation(.easeOut(duration: 0.2)) { showEgg = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.2) {
                withAnimation(.easeIn(duration: 0.5)) { showEgg = false }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(viewport: model.viewport)
                .environmentObject(model)
        }
        .sheet(isPresented: $showShare) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 9) {
            VStack(alignment: .leading, spacing: 1) {
                Text("函数绘图器")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text("\(visibleCount) 条曲线")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            roundButton("arrow.counterclockwise") { model.resetViewport() }
            roundButton("square.and.arrow.up") { exportPNG() }
            roundButton("gearshape") { showSettings = true }
        }
        .padding(.horizontal, 4)
    }

    private var visibleCount: Int {
        model.functions.filter { $0.isVisible && $0.expr != nil }.count
    }

    private func roundButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.85))
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.55), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 画布

    private var plotCard: some View {
        PlotCanvas(viewport: model.viewport)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 18, y: 8)
            .frame(maxHeight: .infinity)
    }

    // MARK: - 方程面板

    private var equationPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("方程")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        model.addFunction()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("添加方程")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.5), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 7)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(model.functions) { item in
                        EquationRow(item: item)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .frame(maxHeight: 244)
            .scrollIndicators(.hidden)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 14, y: 6)
    }

    // MARK: - 导出

    private func exportPNG() {
        let content = PlotCanvas(viewport: model.viewport, exportMode: true)
            .environmentObject(model)
            .frame(width: 1400, height: 1000)
            .background(Color.white)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2

        guard let image = renderer.uiImage else { return }
        shareImage = image

        if model.animations {
            withAnimation(.easeOut(duration: 0.2)) { showShare = true }
        } else {
            showShare = true
        }
    }
}

/// 背景: 渐变 + 三团高斯模糊光斑 (系统 blur, 不是自绘 shader)
struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: scheme == .dark
                ? [Color(red: 0.07, green: 0.08, blue: 0.13),
                   Color(red: 0.10, green: 0.09, blue: 0.16),
                   Color(red: 0.06, green: 0.11, blue: 0.14)]
                : [Color(red: 0.92, green: 0.95, blue: 1.00),
                   Color(red: 0.97, green: 0.94, blue: 1.00),
                   Color(red: 0.92, green: 0.99, blue: 0.99)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    Circle()
                        .fill(Color(red: 0.45, green: 0.62, blue: 1.0).opacity(scheme == .dark ? 0.35 : 0.5))
                        .frame(width: w * 0.8, height: w * 0.8)
                        .offset(x: -w * 0.28, y: -h * 0.28)
                        .blur(radius: 90)

                    Circle()
                        .fill(Color(red: 1.0, green: 0.55, blue: 0.75).opacity(scheme == .dark ? 0.25 : 0.4))
                        .frame(width: w * 0.7, height: w * 0.7)
                        .offset(x: w * 0.32, y: -h * 0.12)
                        .blur(radius: 100)

                    Circle()
                        .fill(Color(red: 0.40, green: 0.85, blue: 0.78).opacity(scheme == .dark ? 0.22 : 0.38))
                        .frame(width: w * 0.75, height: w * 0.75)
                        .offset(x: -w * 0.2, y: h * 0.34)
                        .blur(radius: 100)
                }
            }
        }
        .ignoresSafeArea()
    }
}
