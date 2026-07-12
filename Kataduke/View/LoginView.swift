import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                Text("メールでログイン")
                    .font(.largeTitle.bold())

                VStack(spacing: 12) {
                    TextField("メールアドレス", text: $authViewModel.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)

                    SecureField("パスワード", text: $authViewModel.password)
                        .textFieldStyle(.roundedBorder)
                }

                if let message = authViewModel.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await authViewModel.signIn() }
                } label: {
                    if authViewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("ログイン")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(authViewModel.isLoading)

                Button {
                    Task { await authViewModel.signUp() }
                } label: {
                    Text("新規登録")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(authViewModel.isLoading)

                Spacer()
            }
            .padding()
        }
    }
}
