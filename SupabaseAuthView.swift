import SwiftUI

/// Écran d'authentification Supabase — sign up / sign in
/// Accessible via le profil quand l'utilisateur n'est pas connecté
struct SupabaseAuthView: View {
    @EnvironmentObject private var supabase: SupabaseService
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text(isSignUp ? "CRÉER UN COMPTE" : "CONNEXION")
                            .font(.custom("ClashDisplay-Bold", size: 28))
                            .foregroundColor(.black)

                        Text(isSignUp
                             ? "Rejoins la chasse aux couleurs."
                             : "Retrouve tes frames et tes amis.")
                            .font(.custom("ClashDisplay-Regular", size: 14))
                            .foregroundColor(Color(UIColor.systemGray))
                    }
                    .padding(.top, 40)

                    // Champs
                    VStack(spacing: 14) {
                        if isSignUp {
                            TextField("Username", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textFieldStyle(.plain)
                                .padding(14)
                                .background(Color(UIColor.systemGray6))

                            TextField("Nom affiché", text: $displayName)
                                .textFieldStyle(.plain)
                                .padding(14)
                                .background(Color(UIColor.systemGray6))
                        }

                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.emailAddress)
                            .textFieldStyle(.plain)
                            .padding(14)
                            .background(Color(UIColor.systemGray6))

                        SecureField("Mot de passe", text: $password)
                            .textContentType(isSignUp ? .newPassword : .password)
                            .textFieldStyle(.plain)
                            .padding(14)
                            .background(Color(UIColor.systemGray6))
                    }

                    // Erreur
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.custom("ClashDisplay-Regular", size: 13))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    // Bouton principal
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isSignUp ? "CRÉER LE COMPTE" : "SE CONNECTER")
                                .font(.custom("ClashDisplay-Bold", size: 14))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundColor(.white)
                        .background(canSubmit ? Color.black : Color(UIColor.systemGray4))
                    }
                    .disabled(!canSubmit || isLoading)

                    // Toggle sign up / sign in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSignUp.toggle()
                            errorMessage = nil
                        }
                    } label: {
                        Text(isSignUp
                             ? "Déjà un compte ? Se connecter"
                             : "Pas de compte ? S'inscrire")
                            .font(.custom("ClashDisplay-Medium", size: 13))
                            .foregroundColor(.black)
                    }
                }
                .padding(24)
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") { dismiss() }
                        .font(.custom("ClashDisplay-Medium", size: 14))
                        .foregroundColor(.black)
                }
            }
            .onChange(of: supabase.isAuthenticated) { _, authenticated in
                if authenticated { dismiss() }
            }
        }
    }

    private var canSubmit: Bool {
        guard !email.isEmpty, !password.isEmpty, password.count >= 6 else { return false }
        if isSignUp {
            return !username.isEmpty
        }
        return true
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil

        do {
            if isSignUp {
                try await supabase.signUp(
                    email: email,
                    password: password,
                    username: username,
                    displayName: displayName.isEmpty ? username : displayName
                )
            } else {
                try await supabase.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    SupabaseAuthView()
        .environmentObject(SupabaseService.shared)
}
