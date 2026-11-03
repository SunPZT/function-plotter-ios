import SwiftUI

struct EquationRow: View {
    @EnvironmentObject private var model: PlotModel
    let item: PlotFunction

    @State private var offset: CGFloat = 0
    @State private var deleting = false
    @State private var blurRadius: CGFloat = 0
    @State private var collapsed = false

    private var color: Color {
        PlotModel.palette[item.colorIndex % PlotModel.palette.count]
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { model.function(item.id)?.text ?? item.text },
            set: { model.setText($0, for: item.id) }
        )
    }

    var body: some View {
        ZStack(alignment: .leading) {
            deleteBackground

            rowContent
                .offset(x: offset)
                .blur(radius: blurRadius)
        }
        .frame(height: collapsed ? 0 : 46)
        .opacity(collapsed ? 0 : 1)
        .clipped()
        .simultaneousGesture(swipeGesture)
    }

    private var deleteBackground: some View {
        HStack(spacing: 6) {
            Image(systemName: "trash")
                .font(.system(size: 13, weight: .semibold))
            Text("删除")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.leading, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(red: 0.93, green: 0.25, blue: 0.26),
                                    Color(red: 0.82, green: 0.16, blue: 0.18)],
                           startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(offset > 4 ? 1 : 0)
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
                .shadow(color: color.opacity(0.5), radius: 3)

            Text("y =")
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundStyle(.secondary)

            TextField("输入函数，如 sin(x)", text: textBinding)
                .font(.system(size: 15, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .keyboardType(.asciiCapable)
                .submitLabel(.done)
                .foregroundStyle(item.hasError
                                 ? Color(red: 0.85, green: 0.22, blue: 0.24)
                                 : Color.primary)

            Button {
                withAnimation(.easeOut(duration: 0.18)) { model.toggleVisible(item.id) }
            } label: {
                Image(systemName: item.isVisible ? "eye" : "eye.slash")
                    .font(.system(size: 13))
                    .foregroundStyle(item.isVisible ? Color.secondary : Color.secondary.opacity(0.4))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)

            Button {
                startDeleteAnimation()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(item.hasError
                              ? Color(red: 0.88, green: 0.28, blue: 0.30).opacity(0.8)
                              : Color.white.opacity(0.5),
                              lineWidth: 0.9)
        )
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard !deleting else { return }
                if value.translation.width > 0 {
                    offset = min(104, value.translation.width)
                }
            }
            .onEnded { value in
                guard !deleting else { return }
                if value.translation.width > 66 {
                    startDeleteAnimation()
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) { offset = 0 }
                }
            }
    }

    private func startDeleteAnimation() {
        guard !deleting else { return }
        deleting = true

        withAnimation(.easeOut(duration: 0.22)) { offset = 104 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.easeInOut(duration: 0.28)) { blurRadius = 8 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            withAnimation(.easeIn(duration: 0.26)) { collapsed = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.80) {
            model.remove(item.id)
        }
    }
}
