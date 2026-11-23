import SwiftUI
import WatchKit

@main
struct ModiFiTWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            WatchWorkoutView(model: delegate.model, live: delegate.live)
                .modifier(AppTheme(palette: delegate.model.palette))
                .environment(\.colorScheme, .dark)
                .task { delegate.start() }
        }
    }
}
