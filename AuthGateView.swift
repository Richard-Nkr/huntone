import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject private var viewModel: HuntoneViewModel
    @EnvironmentObject private var supabase: SupabaseService

    var body: some View {
        Group {
            if supabase.isLoading {
                splashScreen
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
        .animation(.easeInOut(duration: 0.3), value: supabase.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: supabase.needsOnboarding)
        .animation(.easeInOut(duration: 0.3), value: supabase.needsTutorial)
        .animation(.easeInOut(duration: 0.3), value: supabase.isLoading)
    }

    private var splashScreen: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 24) {
                Image(uiImage: UIImage(named: "home") ?? UIImage())
                    .resizable()
                    .scaledToFit()
                    .frame(width: 500, height: 500)

                VStack(spacing: 8) {
                    Text("Huntone")
                        .font(.custom("ClashDisplay-Bold", size: 32))
                        .foregroundColor(.black)

                    Text(String(localized: "splash.tagline"))
                        .font(.custom("ClashDisplay-Regular", size: 14))
                        .foregroundColor(Color(UIColor.systemGray))
                }
            }
        }
    }
}

#Preview {
    AuthGateView()
        .environmentObject(HuntoneViewModel())
        .environmentObject(SupabaseService.shared)
}