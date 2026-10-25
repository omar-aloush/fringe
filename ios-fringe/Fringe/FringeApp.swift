import SwiftUI

@main
struct FringeApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(app)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    if url.host == "demo-tour" || url.absoluteString.contains("demo-tour") {
                        app.runDemoTour()
                    }
                }
                .task {
                    if ProcessInfo.processInfo.arguments.contains("-demo-tour") {
                        try? await Task.sleep(for: .seconds(6))
                        app.runDemoTour()
                    }
                }
        }
    }
}
