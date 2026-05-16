import PhotosUI
import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject private var supabase: SupabaseService
    @Environment(\.dismiss) private var dismiss

    @State private var username: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var isLoading = false
    @State private var isChecking = false
    @State private var usernameError: String?
    @FocusState private var isFocused: Bool

    private let originalUsername: String
    private let currentAvatarURL: String?
    private let currentInitial: String

    private var hasChanges: Bool {
        let clean = sanitize(username)
        return clean != originalUsername || avatarImage != nil
    }

    init(username: String, avatarURL: String?) {
        _username = State(initialValue: username)
        self.originalUsername = username
        self.currentAvatarURL = avatarURL
        self.currentInitial = username.prefix(1).uppercased()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        ZStack {
                            if let avatarImage {
                                Image(uiImage: avatarImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else if let avatarURL = currentAvatarURL,
                                      let url = URL(string: avatarURL) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                    default:
                                        avatarPlaceholder
                                    }
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                            } else {
                                avatarPlaceholder
                            }

                            Circle()
                                .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                                .frame(width: 100, height: 100)

                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.black)
                                        .clipShape(Circle())
                                        .offset(x: 4, y: 4)
                                }
                            }
                            .frame(width: 100, height: 100)
                        }
                    }
                    .onChange(of: selectedPhoto) { _, newItem in
                        Task {
                            guard let data = try? await newItem?.loadTransferable(type: Data.self),
                                  let image = UIImage(data: data) else { return }
                            avatarImage = image
                        }
                    }

                    if avatarImage != nil {
                        Button {
                            avatarImage = nil
                            selectedPhoto = nil
                        } label: {
                            Text(loc("onboarding.remove_photo"))
                                .font(.custom("ClashDisplay-Medium", size: 12))
                                .foregroundColor(.red)
                        }
                    }

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
                        Task { await save() }
                    } label: {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView().tint(.white)
                            }
                            Text(loc("edit_profile.save"))
                                .font(.custom("ClashDisplay-Bold", size: 15))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundColor(.white)
                        .background(hasChanges && !isChecking ? Color.black : Color(UIColor.systemGray4))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!hasChanges || isLoading || isChecking)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .padding(.bottom, 8)
                .background(Color.white)
            }
            .background(Color.white)
            .navigationTitle(loc("edit_profile.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                    }
                }
            }
            .onAppear { isFocused = true }
        }
    }

    // MARK: - Actions

    private func sanitize(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._"))
        let filtered = String(input.unicodeScalars.filter { allowed.contains($0) }).lowercased()
        return String(filtered.prefix(30))
    }

    private func save() async {
        let clean = sanitize(username)
        guard clean.count >= 2 else { return }

        isLoading = true
        usernameError = nil

        if clean != originalUsername {
            isChecking = true
            do {
                let available = try await supabase.checkUsernameAvailability(clean)
                isChecking = false
                guard available else {
                    usernameError = loc("onboarding.username_taken")
                    isLoading = false
                    return
                }
            } catch {
                isChecking = false
                usernameError = error.localizedDescription
                isLoading = false
                return
            }
        }

        do {
            try await supabase.completeOnboarding(username: clean, avatarImage: avatarImage)
            usernameError = nil
            dismiss()
        } catch {
            let nsError = error as NSError
            if nsError.domain == "Supabase" || error.localizedDescription.lowercased().contains("duplicate") {
                usernameError = loc("onboarding.username_taken")
            } else {
                usernameError = error.localizedDescription
            }
        }

        isLoading = false
    }

    // MARK: - Subviews

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.black)
            .frame(width: 100, height: 100)
            .overlay(
                Text(currentInitial)
                    .font(.custom("ClashDisplay-Bold", size: 40))
                    .foregroundColor(.white)
            )
    }
}

#Preview {
    EditProfileView(username: "huntone", avatarURL: nil)
        .environmentObject(SupabaseService.shared)
}
