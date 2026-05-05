import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var supabase: SupabaseService

    @State private var username = ""
    @State private var displayName = ""
    @State private var bio = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var usernameError: String?
    @FocusState private var focusedField: Field?

    enum Field { case username, displayName, bio }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "onboarding.welcome"))
                            .font(.custom("ClashDisplay-Medium", size: 11))
                            .foregroundColor(Color(UIColor.systemGray))
                            .tracking(2)

                        Text(String(localized: "onboarding.title"))
                            .font(.custom("ClashDisplay-Bold", size: 32))
                            .foregroundColor(.black)
                            .lineSpacing(4)

                        Text(String(localized: "onboarding.subtitle"))
                            .font(.custom("ClashDisplay-Regular", size: 14))
                            .foregroundColor(Color(UIColor.systemGray))
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "onboarding.username_label"))
                                .font(.custom("ClashDisplay-Medium", size: 10))
                                .foregroundColor(Color(UIColor.systemGray))
                                .tracking(1.5)

                            HStack(spacing: 0) {
                                Text("@")
                                    .font(.custom("ClashDisplay-Bold", size: 18))
                                    .foregroundColor(Color(UIColor.systemGray))
                                    .padding(.leading, 14)

                                TextField(String(localized: "onboarding.username_placeholder"), text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.plain)
                                    .font(.custom("ClashDisplay-Bold", size: 18))
                                    .focused($focusedField, equals: .username)
                                    .onChange(of: username) { _, newValue in
                                        username = sanitize(newValue)
                                        usernameError = nil
                                    }
                            }
                            .padding(.vertical, 12)
                            .background(Color(UIColor.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                            if let usernameError {
                                Text(usernameError)
                                    .font(.custom("ClashDisplay-Regular", size: 12))
                                    .foregroundColor(.red)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "onboarding.display_name_label"))
                                .font(.custom("ClashDisplay-Medium", size: 10))
                                .foregroundColor(Color(UIColor.systemGray))
                                .tracking(1.5)

                            TextField(String(localized: "onboarding.display_name_placeholder"), text: $displayName)
                                .textFieldStyle(.plain)
                                .font(.custom("ClashDisplay-Bold", size: 18))
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                                .background(Color(UIColor.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .focused($focusedField, equals: .displayName)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "onboarding.bio_label"))
                                .font(.custom("ClashDisplay-Medium", size: 10))
                                .foregroundColor(Color(UIColor.systemGray))
                                .tracking(1.5)

                            TextField(String(localized: "onboarding.bio_placeholder"), text: $bio, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.custom("ClashDisplay-Regular", size: 15))
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                                .background(Color(UIColor.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .focused($focusedField, equals: .bio)
                                .onChange(of: bio) { _, newValue in
                                    if newValue.count > 160 { bio = String(newValue.prefix(160)) }
                                }

                            Text("\(bio.count)/160")
                                .font(.custom("ClashDisplay-Regular", size: 11))
                                .foregroundColor(bio.count > 150 ? .orange : Color(UIColor.systemGray))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.custom("ClashDisplay-Regular", size: 13))
                            .foregroundColor(.red)
                            .padding(.vertical, 8)
                    }
                }
                .padding(24)
            }

            VStack(spacing: 16) {
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        }
                        Text(String(localized: "onboarding.submit_button"))
                            .font(.custom("ClashDisplay-Bold", size: 14))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .foregroundColor(.white)
                    .background(canSubmit ? Color.black : Color(UIColor.systemGray4))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canSubmit || isLoading)
                .padding(.horizontal, 24)

                Text(String(localized: "onboarding.edit_later"))
                    .font(.custom("ClashDisplay-Regular", size: 12))
                    .foregroundColor(Color(UIColor.systemGray))
                    .padding(.bottom, 48)
            }
        }
        .background(Color.white)
        .task {
            focusedField = .username
        }
    }

    private var canSubmit: Bool {
        username.count >= 2 && !displayName.isEmpty
    }

    private func sanitize(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._"))
        let filtered = String(input.unicodeScalars.filter { allowed.contains($0) }).lowercased()
        return String(filtered.prefix(30))
    }

    private func submit() async {
        guard canSubmit else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await supabase.completeOnboarding(username: username, displayName: displayName)
            supabase.needsTutorial = true
        } catch {
            let nsError = error as NSError
            if nsError.domain == "Supabase" || error.localizedDescription.lowercased().contains("duplicate") {
                usernameError = String(localized: "onboarding.username_taken")
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }
}

#Preview {
    OnboardingView()
        .environmentObject(SupabaseService.shared)
}