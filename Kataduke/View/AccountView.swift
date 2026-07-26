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

                if isEditingProfile {
                    Button {
                        focusedField = nil
                        isShowingIconSourceOptions = true
                    } label: {
                        Label("アイコンを変更", systemImage: "photo")
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            Section("プロフィール") {
                LabeledContent("メールアドレス") {
                    Text(profileViewModel.email)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                if isEditingProfile {
                    TextField("名前", text: $profileViewModel.name)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)
                } else {
                    LabeledContent("名前") {
                        Text(profileViewModel.name.isEmpty ? "未設定" : profileViewModel.name)
                            .foregroundStyle(profileViewModel.name.isEmpty ? .secondary : .primary)
                    }
                }
            }

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
