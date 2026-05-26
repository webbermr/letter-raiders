import SwiftUI

@main
struct LetterRaidersApp: App {
    init() {
        FontRegistration.register()
        WordDictionary.shared.preload()
        _ = GameAudio.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
    }
}
