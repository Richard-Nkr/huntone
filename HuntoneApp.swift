import SwiftUI

@main
struct HuntoneApp: App {
    @StateObject private var viewModel = HuntoneViewModel()
    @StateObject private var socialViewModel = SocialViewModel()
    @StateObject private var supabaseService = SupabaseService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(socialViewModel)
                .environmentObject(supabaseService)
                .task {
                    // Restaure la session Supabase si un token existe
                    await supabaseService.restoreSession()
                }
        }
    }
}
