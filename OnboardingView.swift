import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var supabase: SupabaseService

    @State private var username = ""
    @State private var isLoading = false
    @State private var isChecking = false
    @State private var usernameError: String?
    @FocusState private var isFocused: Bool

    private var isValid: Bool {
        let clean = sanitize(username)
        return clean.count >= 2 && clean.count <= 30
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Text("Huntone")
                    .font(.custom("Comico-Regular", size: 40))
                    .foregroundColor(.black)

                VStack(spacing: 8) {
                    Text(loc("onboarding.username_label"))
                        .font(.custom("ClashDisplay-Medium", size: 10))
                        .foregroundColor(Color(UIColor.systemGray))
                        .tracking(1.5)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("@\(loc("onboarding.username_placeholder"))", text: $username)
                        .textFieldStyle(.plain)
                        .font(.custom("ClashDisplay-Bold", size: 22))
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(Color(UIColor.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isFocused)
                        .onChange(of: username) { _, newValue in
                            username = sanitize(newValue)
                            usernameError = nil
                        }
                }

                if isChecking {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text(loc("onboarding.checking"))
                            .font(.custom("ClashDisplay-Regular", size: 13))
                            .foregroundColor(Color(UIColor.systemGray))
                    }
                }

                if let usernameError {
                    Text(usernameError)
                        .font(.custom("ClashDisplay-Regular", size: 13))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 12) {
                Divider()

                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView().tint(.white)
                        }
                        Text(loc("onboarding.create_profile"))
                            .font(.custom("ClashDisplay-Bold", size: 15))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(.white)
                    .background(isValid && !isChecking ? Color.black : Color(UIColor.systemGray4))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!isValid || isLoading || isChecking)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .padding(.bottom, 8)
            .background(Color.white)
        }
        .background(Color.white)
        .onAppear {
            isFocused = true
        }
    }

    // MARK: - Actions

    private func sanitize(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._"))
        let filtered = String(input.unicodeScalars.filter { allowed.contains($0) }).lowercased()
        return String(filtered.prefix(30))
    }

    private func submit() async {
        let clean = sanitize(username)
        guard clean.count >= 2 else { return }

        isLoading = true
        isChecking = true
        usernameError = nil

        do {
            let available = try await supabase.checkUsernameAvailability(clean)
            isChecking = false

            guard available else {
                usernameError = loc("onboarding.username_taken")
                isLoading = false
                return
            }

            try await supabase.completeOnboarding(username: clean)
            supabase.needsTutorial = true
        } catch {
            isChecking = false
            let nsError = error as NSError
            if nsError.domain == "Supabase" || error.localizedDescription.lowercased().contains("duplicate") {
                usernameError = loc("onboarding.username_taken")
            } else {
                usernameError = error.localizedDescription
            }
        }

        isLoading = false
    }
}

#Preview {
    OnboardingView()
        .environmentObject(SupabaseService.shared)
}
