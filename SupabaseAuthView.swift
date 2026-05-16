import AuthenticationServices
import CryptoKit
import SwiftUI

// MARK: - Phone Card Model

private struct PhoneCard: Identifiable {
    let id: String
    let imageName: String
    let accentHex: String
}

// MARK: - SupabaseAuthView

struct SupabaseAuthView: View {
    @EnvironmentObject private var supabase: SupabaseService

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var appleDelegate: AppleSignInDelegate?

    private let cards: [PhoneCard] = [
        PhoneCard(id: "yellow", imageName: "yellow", accentHex: "#E9C46A"),
        PhoneCard(id: "purple", imageName: "purple", accentHex: "#9B5DE5"),
        PhoneCard(id: "blue",   imageName: "blue",   accentHex: "#2667FF"),
        PhoneCard(id: "green",  imageName: "green",  accentHex: "#2A9D8F"),
        PhoneCard(id: "orange", imageName: "orange", accentHex: "#F4A261"),
        PhoneCard(id: "red",    imageName: "red",    accentHex: "#E63946"),
    ]

    private let cardSize: CGFloat = 175
    private let cardRatio: CGFloat = 4.0 / 3.0

    // Proportional spread — 2top / 2mid / 2bottom
    private let placements: [(x: CGFloat, y: CGFloat, rot: Double)] = [
        (-0.42, -0.70,  -6),   // yellow  — top left
        ( 0.42, -0.60,   7),   // purple  — top right
        (-0.30, -0.15,  -4),   // blue    — mid left
        ( 0.30, -0.05,   5),   // green   — mid right
        (-0.48,  0.35,  -8),   // orange  — bottom left
        ( 0.44,  0.45,   6),   // red     — bottom right
    ]

    var body: some View {
        GeometryReader { screen in
            VStack(spacing: 0) {
                pileSection(in: screen)
                    .frame(height: screen.size.height * 0.75)

                VStack(spacing: 8) {
                    Text("Huntone")
                        .font(.custom("Comico-Regular", size: 32))
                        .foregroundColor(.black)

                    Text(loc("splash.tagline"))
                        .font(.custom("ClashDisplay-Regular", size: 14))
                        .foregroundColor(Color(UIColor.systemGray))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                }

                Spacer().frame(height: 12)

                VStack(spacing: 10) {
                    Button {
                        Task { await handleAppleSignIn() }
                    } label: {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 20))
                            }
                            Text(loc("auth.continue_apple"))
                                .font(.custom("ClashDisplay-Medium", size: 17))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundColor(.white)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 32)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.custom("ClashDisplay-Regular", size: 13))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }

                Spacer(minLength: 8)
            }
            .background(Color.white)
            }
    }

    // MARK: - Pile méli-mélo

    private func pileSection(in geo: GeometryProxy) -> some View {
        let zoneH = geo.size.height * 0.75

        return ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                let (px, py, rot) = placements[index]

                phoneCard(card)
                    .offset(x: px * geo.size.width * 0.85, y: py * zoneH * 0.55)
                    .rotationEffect(.degrees(rot))
                    .zIndex(Double(index))
            }
        }
        .frame(height: zoneH)
    }

    private func phoneCard(_ card: PhoneCard) -> some View {
        let h = cardSize * cardRatio
        let accent = Color(uiColor: UIColor(hex: card.accentHex))

        return ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.10), radius: 12, y: 4)

            if let img = UIImage(named: card.imageName) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cardSize - 4, height: h - 4)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }

            RoundedRectangle(cornerRadius: 22)
                .stroke(accent.opacity(0.25), lineWidth: 1)
        }
        .frame(width: cardSize, height: h)
    }

    // MARK: - Apple Sign-In

    private func handleAppleSignIn() async {
        isLoading = true
        errorMessage = nil

        let rawNonce = randomNonceString()
        let sha256Nonce = sha256(rawNonce)

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256Nonce

        let delegate = AppleSignInDelegate { result in
            Task { @MainActor in
                switch result {
                case .success(let (idToken, fullName, email)):
                    do {
                        try await supabase.signInWithApple(idToken: idToken, nonce: rawNonce)
                        if let fullName, let displayName = formattedDisplayName(fullName) {
                            UserDefaults.standard.set(displayName, forKey: "\(SupabaseConfig.defaultsPrefix).appleDisplayName")
                        }
                        if let email {
                            UserDefaults.standard.set(email, forKey: "\(SupabaseConfig.defaultsPrefix).appleEmail")
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                case .failure(let error):
                    if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                        errorMessage = error.localizedDescription
                    }
                }
                isLoading = false
                appleDelegate = nil
            }
        }
        appleDelegate = delegate

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = delegate
        controller.presentationContextProvider = delegate
        controller.performRequests()
    }
}

// MARK: - Apple Sign-In Delegate

private final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let completion: (Result<(idToken: String, fullName: PersonNameComponents?, email: String?), Error>) -> Void

    init(completion: @escaping (Result<(idToken: String, fullName: PersonNameComponents?, email: String?), Error>) -> Void) {
        self.completion = completion
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let idTokenData = credential.identityToken,
              let idToken = String(data: idTokenData, encoding: .utf8) else {
            completion(.failure(SBError.invalidResponse))
            return
        }
        completion(.success((idToken, credential.fullName, credential.email)))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIWindow()
        }
        return window
    }
}

// MARK: - Nonce Utilities

private func randomNonceString(length: Int = 32) -> String {
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length
    while remainingLength > 0 {
        var randoms = [UInt8](repeating: 0, count: 16)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
        if errorCode != errSecSuccess { break }
        for random in randoms {
            if remainingLength == 0 { break }
            result.append(charset[Int(random) % charset.count])
            remainingLength -= 1
        }
    }
    return result
}

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    return hashedData.compactMap { String(format: "%02x", $0) }.joined()
}

private func formattedDisplayName(_ name: PersonNameComponents) -> String? {
    let formatter = PersonNameComponentsFormatter()
    formatter.style = .default
    return formatter.string(from: name)
}

#Preview {
    SupabaseAuthView()
        .environmentObject(SupabaseService.shared)
}
