import SwiftUI

@main
struct ServiceBellApp: App {
    var body: some Scene {
        WindowGroup {
            BellScreen()
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        }
    }
}
