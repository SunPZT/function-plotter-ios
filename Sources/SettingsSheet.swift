import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject private var model: PlotModel
    @ObservedObject private var viewport: Viewport
    @Environment(\.dismiss) private var dismiss

    init(viewport: Viewport) {
        self.viewport = viewport
    }

    var body: some View {
        NavigationStack {
            List {
                Section("绘图") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("采样点数")
                            Spacer()
                            Text("\(model.sampleCount)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: Binding(
                                get: { Double(model.sampleCount) },
                                set: { model.sampleCount = Int($0) }
                            ),
                            in: 400...4000,
                            step: 100
                        )
                        Text("曲线越复杂，采样点越多越平滑")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("线宽")
                            Spacer()
                            Text(String(format: "%.1f", model.lineWidth))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $model.lineWidth, in: 1...6, step: 0.2)
                    }
                }

                Section("显示") {
                    Toggle("显示网格", isOn: $model.showGrid)
                    Toggle("显示图例", isOn: $model.showLegend)
                    Toggle("极点处断开曲线", isOn: $model.breakPoles)
                    Toggle("动画效果", isOn: $model.animations)
                }

                Section("视图") {
                    HStack {
                        Text("当前范围")
                        Spacer()
                        Text("x \(format(model.viewport.x0)) ~ \(format(model.viewport.x1))")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Button("恢复默认范围") {
                        model.resetViewport()
                    }
                }

                Section("使用说明") {
                    VStack(alignment: .leading, spacing: 10) {
                        tip("输入函数", "直接输 sin(x)、0.1x^2、2x、ln(x)，乘号可以省略")
                        tip("双指缩放", "两指张开或捏合，以屏幕中心为基准缩放")
                        tip("拖动平移", "单指拖动整个图像")
                        tip("双击复位", "双击画布恢复默认的 -10 ~ 10 范围")
                        tip("显隐与删除", "点眼睛图标隐藏曲线；点 ✕ 或向右滑动可删除方程")
                        tip("导出图片", "右上角分享按钮可把当前图像存成 PNG")
                        tip("自动保存", "所有设置和函数都会自动保存在本机")
                    }
                    .padding(.vertical, 2)
                }

                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0")
                            .foregroundStyle(.secondary)
                    }
                    Text("为 iOS 16 及以上设计，界面采用系统材质的高斯模糊效果。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(.ultraThinMaterial)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func tip(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private func format(_ value: Double) -> String {
        if abs(value) >= 1000 || (abs(value) < 0.01 && value != 0) {
            return String(format: "%.1e", value)
        }
        return String(format: "%.1f", value)
    }
}
