import SwiftUI

@main
struct FunctionPlotterApp: App {
    @StateObject private var model = PlotModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
    }
}
