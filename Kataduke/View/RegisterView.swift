import SwiftUI
import UIKit

struct RegisterView: View {
    private enum RegisterField: Hashable {
        case email
        case password
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
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var iconImage: UIImage?
    @State private var isShowingIconSourceOptions = false
    @State private var iconPickerSource: IconPickerSource?
    @FocusState private var focusedField: RegisterField?

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
                    Label("アイコンを選ぶ（任意）", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
            }

            Section("新規登録") {
                TextField("メールアドレス", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)

                SecureField("パスワード", text: $password)
                    .focused($focusedField, equals: .password)

                TextField("名前", text: $name)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .name)
            }

            if let message = authViewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Section {
                Button {
                    focusedField = nil
                    Task {
                        let didSignUp = await authViewModel.signUp(
                            email: email,
                            password: password,
                            name: name,
                            iconImage: iconImage
                        )
                        if didSignUp {
                            dismiss()
                        }
                    }
                } label: {
                    if authViewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("登録する")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(authViewModel.isLoading)
            }
        }
        .navigationTitle("新規登録")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            focusedField = nil
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
            RegisterIconPickerView(sourceType: source.sourceType) { image in
                iconImage = image
                iconPickerSource = nil
            } onCancel: {
                iconPickerSource = nil
            }
        }
    }

    @ViewBuilder
    private var profileIcon: some View {
        if let iconImage {
            Image(uiImage: iconImage)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .frame(width: 120, height: 120)
        }
    }
}

private struct RegisterIconPickerView: UIViewControllerRepresentable {
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
        let parent: RegisterIconPickerView

        init(_ parent: RegisterIconPickerView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
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
