import Foundation
import FirebaseAuth

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
