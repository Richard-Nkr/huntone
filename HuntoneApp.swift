import SwiftUI
import SwiftData

@main
struct HuntoneApp: App {
    @StateObject private var viewModel = HuntoneViewModel()
    @StateObject private var supabaseService = SupabaseService.shared
    @StateObject private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            AuthGateView()
                .environmentObject(viewModel)
                .environmentObject(supabaseService)
                .environmentObject(languageManager)
                .id(languageManager.current)
                .task {
                    await supabaseService.restoreSession()
                }
        }
        .modelContainer(for: [DailyGrid.self, GridCell.self])
    }
}