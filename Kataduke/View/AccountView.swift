import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct AccountView: View {
    private enum ProfileField: Hashable {
        case name
        case friendCode
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
    @State private var isShowingIconSourceOptions = false
    @State private var iconPickerSource: IconPickerSource?
    @State private var isShowingQRScanner = false
    @State private var isShowingFriendAddedAlert = false
    @FocusState private var focusedField: ProfileField?
    private let qrContext = CIContext()
    private let qrFilter = CIFilter.qrCodeGenerator()

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    profileIcon
                    Spacer()
                }

                Button {
                    focusedField = nil
                    isShowingIconSourceOptions = true
                } label: {
                    Label("アイコンを選ぶ", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
            }

            Section("プロフィール") {
                LabeledContent("メールアドレス") {
                    Text(profileViewModel.email)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                TextField("名前", text: $profileViewModel.name)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .name)
            }

            Section {
                Button {
                    Task { await profileViewModel.save() }
                } label: {
                    if profileViewModel.isSaving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Firebaseに保存")
                    }
                }
                .buttonStyle(AccountPrimaryButtonStyle())
                .disabled(profileViewModel.isSaving || profileViewModel.isLoading)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

            Section("自分のアカウントコード") {
                VStack(spacing: 14) {
                    if profileViewModel.accountCode.isEmpty {
                        ProgressView()
                    } else {
                        qrCodeImage(for: profileViewModel.accountCode)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 160, height: 160)

                        Text(profileViewModel.accountCode)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("友達登録") {
                TextField("友達のアカウントコード", text: $profileViewModel.friendCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .friendCode)

                Button {
                    focusedField = nil
                    isShowingQRScanner = true
                } label: {
                    Label("QRコードを読み取る", systemImage: "qrcode.viewfinder")
                        .frame(maxWidth: .infinity)
                }
            }

            Section {
                Button {
                    focusedField = nil
                    Task {
                        if await profileViewModel.addFriend() {
                            isShowingFriendAddedAlert = true
                        }
                    }
                } label: {
                    if profileViewModel.isAddingFriend {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("友達を追加")
                    }
                }
                .buttonStyle(AccountPrimaryButtonStyle())
                .disabled(profileViewModel.isAddingFriend || profileViewModel.friendCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

            Section("友達一覧") {
                if profileViewModel.friends.isEmpty {
                    Text("まだ友達がいません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(profileViewModel.friends) { friend in
                        HStack(spacing: 12) {
                            friendIcon(url: friend.iconURL)
                            Text(friend.name)
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if let message = profileViewModel.message {
                Text(message).foregroundStyle(.green)
            }
            if let message = profileViewModel.errorMessage {
                Text(message).foregroundStyle(.red)
            }

            Section {
                Button("ログアウト", role: .destructive) {
                    authViewModel.signOut()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            focusedField = nil
        }
        .navigationTitle("アカウント")
        .task {
            await profileViewModel.load()
            await profileViewModel.prepareAccountCodeIfNeeded()
            await profileViewModel.refreshFriends()
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
        .fullScreenCover(isPresented: $isShowingQRScanner) {
            QRCodeScannerView { code in
                isShowingQRScanner = false
                profileViewModel.friendCode = code
                Task {
                    if await profileViewModel.addFriend() {
                        isShowingFriendAddedAlert = true
                    }
                }
            } onCancel: {
                isShowingQRScanner = false
            }
            .ignoresSafeArea()
        }
        .alert("友達を追加しました。", isPresented: $isShowingFriendAddedAlert) {
            Button("OK") {
                isShowingFriendAddedAlert = false
            }
        }
    }

    @ViewBuilder
    private var profileIcon: some View {
        if let image = profileViewModel.iconImage {
            Image(uiImage: image).resizable().scaledToFill()
                .frame(width: 120, height: 120).clipShape(Circle())
        } else if let url = profileViewModel.iconURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 120, height: 120).clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable().scaledToFit().foregroundStyle(.secondary)
                .frame(width: 120, height: 120)
        }
    }

    @ViewBuilder
    private func friendIcon(url: URL?) -> some View {
        if let url {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
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

private struct AccountPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(red: 239 / 255, green: 132 / 255, blue: 69 / 255))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
