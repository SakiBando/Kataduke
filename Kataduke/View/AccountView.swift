import SwiftUI
import PhotosUI

struct AccountView: View {
    private enum ProfileField: Hashable {
        case name
        case age
    }

    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var profileViewModel = UserProfileViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @FocusState private var focusedField: ProfileField?

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
        .task { await profileViewModel.load() }
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
}
