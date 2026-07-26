import Foundation
import FirebaseAuth
import UIKit

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var errorMessage: String?
    @Published var isLoading = false

    init() {
        self.user = Auth.auth().currentUser
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.user = user
            }
        }
    }

    var isSignedIn: Bool {
        user != nil
    }

    func signIn() async {
        await signInOrCreateAccount(mode: .signIn)
    }

    func signUp() async {
        await signInOrCreateAccount(mode: .signUp)
    }

    func signUp(email: String, password: String, name: String, iconImage: UIImage?) async -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            errorMessage = "メールアドレスを入力してください"
            return false
        }
        guard password.count >= 6 else {
            errorMessage = "パスワードは6文字以上にしてください"
            return false
        }
        guard !trimmedName.isEmpty else {
            errorMessage = "名前を入力してください"
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await Auth.auth().createUser(withEmail: trimmedEmail, password: password)
            _ = try await UserProfileService().saveProfile(
                userID: result.user.uid,
                name: trimmedName,
                iconImage: iconImage
            )
            self.email = trimmedEmail
            self.password = password
            user = result.user
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            user = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private enum Mode {
        case signIn
        case signUp
    }

    private func signInOrCreateAccount(mode: Mode) async {
        guard validateInputs() else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            switch mode {
            case .signIn:
                let result = try await Auth.auth().signIn(withEmail: email, password: password)
                user = result.user
            case .signUp:
                let result = try await Auth.auth().createUser(withEmail: email, password: password)
                user = result.user
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validateInputs() -> Bool {
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "メールアドレスを入力してください"
            return false
        }
        if password.count < 6 {
            errorMessage = "パスワードは6文字以上にしてください"
            return false
        }
        return true
    }
}
