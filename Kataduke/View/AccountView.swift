import SwiftUI
import PhotosUI
import CoreImage.CIFilterBuiltins

struct AccountView: View {
    private enum ProfileField: Hashable {
        case name
        case age
        case friendCode
    }

    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var profileViewModel = UserProfileViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
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

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("アイコンを選ぶ", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
            }

            Section("プロフィール") {
                TextField("名前", text: $profileViewModel.name)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .name)
                TextField("年齢", text: $profileViewModel.age)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .age)
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

            Section("友達登録") {
                TextField("友達のアカウントコード", text: $profileViewModel.friendCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .friendCode)

                Button {
                    focusedField = nil
                    Task { await profileViewModel.addFriend() }
                } label: {
                    if profileViewModel.isAddingFriend {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("友達を追加").frame(maxWidth: .infinity)
                    }
                }
                .disabled(profileViewModel.isAddingFriend || profileViewModel.friendCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

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
                Button {
                    Task { await profileViewModel.save() }
                } label: {
                    if profileViewModel.isSaving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Firebaseに保存").frame(maxWidth: .infinity)
                    }
                }
                .disabled(profileViewModel.isSaving || profileViewModel.isLoading)

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
        .onChange(of: selectedPhoto) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                profileViewModel.iconImage = image
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
