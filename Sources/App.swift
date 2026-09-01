import SwiftUI

@main
struct MyTodoApp: App {
    @State private var store = Store()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.rolloverIfNeeded() }
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.significantTimeChangeNotification)) { _ in
                    store.rolloverIfNeeded()
                }
        }
    }
}
