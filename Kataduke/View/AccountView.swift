import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct AccountView: View {
    private enum ProfileField: Hashable {
        case name
    }

    private enum IconPickerSource: Identifiable {
        case camera
        case photoLibrary

        var id: String {
            switch self {
            case .camera:
                return "camera"
            case .photoLibrary:
                return "photoLibrary"
            }
        }

        var sourceType: UIImagePickerController.SourceType {
            switch self {
            case .camera:
                return .camera
            case .photoLibrary:
                return .photoLibrary
            }
        }
    }

    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var profileViewModel = UserProfileViewModel()
    @State private var isEditingProfile = false
    @State private var isShowingIconSourceOptions = false
    @State private var iconPickerSource: IconPickerSource?
    @State private var originalName = ""
    @State private var isShowingSignOutAlert = false
    @State private var isShowingDeleteAccountAlert = false
    @FocusState private var focusedField: ProfileField?
    private let qrContext = CIContext()
    private let qrFilter = CIFilter.qrCodeGenerator()

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                accountHeaderCard
                profileCard
                accountCodeCard
                messageSection
                actionButtons
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 110)
        }
        .background(accountBackground.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            focusedField = nil
        }
        .navigationTitle("アカウント")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isEditingProfile {
                    Button("キャンセル") {
                        cancelEditing()
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if isEditingProfile {
                    Button {
                        Task { await saveProfileFromToolbar() }
                    } label: {
                        if profileViewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(profileViewModel.isSaving || profileViewModel.isLoading)
                } else {
                    Button("編集") {
                        startEditing()
                    }
                }
            }
        }
        .task {
            await profileViewModel.load()
            await profileViewModel.prepareAccountCodeIfNeeded()
        }
        .confirmationDialog("アイコンを選ぶ", isPresented: $isShowingIconSourceOptions, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("写真を撮る") {
                    iconPickerSource = .camera
                }
            }

            Button("カメラロールから選ぶ") {
                iconPickerSource = .photoLibrary
            }

            Button("キャンセル", role: .cancel) { }
        }
        .sheet(item: $iconPickerSource) { source in
            ProfileIconPickerView(sourceType: source.sourceType) { image in
                profileViewModel.iconImage = image
                iconPickerSource = nil
            } onCancel: {
                iconPickerSource = nil
            }
        }
        .alert("ログアウトしますか？", isPresented: $isShowingSignOutAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("ログアウト", role: .destructive) {
                authViewModel.signOut()
            }
        }
        .alert("アカウントを削除しますか？", isPresented: $isShowingDeleteAccountAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                Task {
                    _ = await authViewModel.deleteAccount()
                }
            }
        } message: {
            Text("Firebase上のプロフィールや友達情報も削除されます。この操作は取り消せません。")
        }
    }

    private var accountHeaderCard: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                profileIcon
                    .shadow(color: accountMint.opacity(0.20), radius: 14, x: 0, y: 8)

                if isEditingProfile {
                    Button {
                        focusedField = nil
                        isShowingIconSourceOptions = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(accountMint))
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(profileViewModel.name.isEmpty ? "Kataduke User" : profileViewModel.name)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(accountText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(profileViewModel.email.isEmpty ? "メールアドレス未設定" : profileViewModel.email)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accountMint)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 18)
        .background(accountCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(.white.opacity(0.82), lineWidth: 2))
        .shadow(color: accountMint.opacity(0.12), radius: 16, x: 0, y: 10)
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("プロフィール", systemImage: "person.crop.circle")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(accountMint)

            accountInfoRow(title: "メールアドレス", value: profileViewModel.email.isEmpty ? "未設定" : profileViewModel.email)

            if isEditingProfile {
                VStack(alignment: .leading, spacing: 8) {
                    Text("名前")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    TextField("名前", text: $profileViewModel.name)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)
                        .padding(14)
                        .background(Color.white.opacity(0.76))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(accountMint.opacity(0.20), lineWidth: 1))
                }
            } else {
                accountInfoRow(title: "名前", value: profileViewModel.name.isEmpty ? "未設定" : profileViewModel.name)
            }
        }
        .padding(18)
        .background(accountCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(accountMint.opacity(0.20), lineWidth: 1))
    }

    private var accountCodeCard: some View {
        VStack(spacing: 16) {
            Label("自分のアカウントコード", systemImage: "qrcode")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(accountMint)
                .frame(maxWidth: .infinity, alignment: .leading)

            if profileViewModel.accountCode.isEmpty {
                ProgressView()
                    .tint(accountMint)
                    .frame(height: 190)
            } else {
                qrCodeImage(for: profileViewModel.accountCode)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 170, height: 170)
                    .padding(18)
                    .background(Color.white.opacity(0.84))
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                Text(profileViewModel.accountCode)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(accountText)
                    .textSelection(.enabled)
            }
        }
        .padding(18)
        .background(accountCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(accountMint.opacity(0.20), lineWidth: 1))
    }

    @ViewBuilder
    private var messageSection: some View {
        if let message = profileViewModel.message {
            accountMessageCard(message, color: accountMint)
        }
        if let message = profileViewModel.errorMessage {
            accountMessageCard(message, color: .red)
        }
        if let message = authViewModel.errorMessage {
            accountMessageCard(message, color: .red)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                isShowingSignOutAlert = true
            } label: {
                Text("ログアウト")
            }
            .buttonStyle(AccountDangerButtonStyle())

            Button {
                isShowingDeleteAccountAlert = true
            } label: {
                if authViewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("アカウント削除")
                }
            }
            .buttonStyle(AccountDangerButtonStyle(isFilled: true))
            .disabled(authViewModel.isLoading)
        }
    }

    private func accountInfoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(value == "未設定" ? .secondary : accountText)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func accountMessageCard(_ message: String, color: Color) -> some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.white.opacity(0.76))
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func startEditing() {
        originalName = profileViewModel.name
        isEditingProfile = true
    }

    private func cancelEditing() {
        profileViewModel.name = originalName
        profileViewModel.iconImage = nil
        focusedField = nil
        isEditingProfile = false
    }

    @MainActor
    private func saveProfileFromToolbar() async {
        await profileViewModel.save()
        if profileViewModel.errorMessage == nil {
            focusedField = nil
            isEditingProfile = false
        }
    }

    @ViewBuilder
    private var profileIcon: some View {
        if let image = profileViewModel.iconImage {
            Image(uiImage: image).resizable().scaledToFill()
                .frame(width: 126, height: 126).clipShape(Circle())
        } else if let url = profileViewModel.iconURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 126, height: 126).clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable().scaledToFit().foregroundStyle(.secondary)
                .frame(width: 126, height: 126)
        }
    }

    private func qrCodeImage(for text: String) -> Image {
        qrFilter.message = Data(text.utf8)
        qrFilter.correctionLevel = "M"

        guard let outputImage = qrFilter.outputImage,
              let cgImage = qrContext.createCGImage(outputImage, from: outputImage.extent) else {
            return Image(systemName: "qrcode")
        }
        return Image(decorative: cgImage, scale: 1)
    }
}

private let accountMint = Color(red: 113 / 255, green: 177 / 255, blue: 161 / 255)
private let accountYellow = Color(red: 244 / 255, green: 195 / 255, blue: 91 / 255)
private let accountText = Color(red: 40 / 255, green: 68 / 255, blue: 66 / 255)
private let accountBackground = Color(red: 246 / 255, green: 252 / 255, blue: 247 / 255)
private let accountCardBackground = LinearGradient(
    colors: [
        Color.white.opacity(0.86),
        accountMint.opacity(0.10)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

private struct ProfileIconPickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage?) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ProfileIconPickerView

        init(_ parent: ProfileIconPickerView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let image = info[.editedImage] as? UIImage {
                parent.onImagePicked(image)
            } else if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            } else {
                parent.onImagePicked(nil)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}

private struct AccountDangerButtonStyle: ButtonStyle {
    var isFilled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(isFilled ? .white : .red)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(isFilled ? Color.red : Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
