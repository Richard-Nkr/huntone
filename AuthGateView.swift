import SwiftUI
import SwiftData

struct AuthGateView: View {
    @EnvironmentObject private var viewModel: HuntoneViewModel
    @EnvironmentObject private var supabase: SupabaseService
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        content
            .animation(.easeInOut(duration: 0.3), value: supabase.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: supabase.needsOnboarding)
            .animation(.easeInOut(duration: 0.3), value: supabase.needsTutorial)
            .animation(.easeInOut(duration: 0.3), value: supabase.isLoading)
            .onAppear {
                viewModel.configure(modelContext: modelContext)
            }
    }

    @ViewBuilder
    private var content: some View {
        if supabase.isLoading {
            SupabaseAuthView()
        } else if !supabase.isAuthenticated {
            SupabaseAuthView()
        } else if supabase.needsOnboarding {
            OnboardingView()
        } else if supabase.needsTutorial {
            HowToUseView()
        } else {
            ContentView()
        }
    }
}

#Preview {
    AuthGateView()
        .environmentObject(HuntoneViewModel())
        .environmentObject(SupabaseService.shared)
}