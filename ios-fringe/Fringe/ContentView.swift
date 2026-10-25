import SwiftUI

/// Root tab container: Map, Events, Lab, Guide.
struct ContentView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.tab) {
            Tab("Map", systemImage: "map", value: AppTab.map) {
                RadarMapView()
            }
            Tab("Events", systemImage: "list.bullet", value: AppTab.events) {
                EventsView()
            }
            Tab("Lab", systemImage: "waveform.path.ecg", value: AppTab.lab) {
                LabView()
            }
            Tab("Guide", systemImage: "book", value: AppTab.guide) {
                GuideView()
            }
        }
        .tint(Theme.accent)
        .sensoryFeedback(.selection, trigger: app.tab)
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
        .preferredColorScheme(.dark)
}
