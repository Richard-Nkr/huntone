import SwiftUI

@main
struct HuntoneApp: App {
    @StateObject private var viewModel = HuntoneViewModel()
    @StateObject private var socialViewModel = SocialViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(socialViewModel)
        }
    }
}
