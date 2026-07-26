//
//  ShareView.swift
//  Kataduke
//
//  Created by Saki on 2026/07/25.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct ShareView: View {
    private enum FriendSheet: Identifiable {
        case myCode
        case addFriend
        case friends

        var id: String {
            switch self {
            case .myCode:
                return "myCode"
            case .addFriend:
                return "addFriend"
            case .friends:
                return "friends"
            }
        }
    }

    @State private var records: [SharedCleaningRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var friendSheet: FriendSheet?
    private let service = SharedCleaningRecordService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if records.isEmpty {
                    ContentUnavailableView("共有された記録はありません", systemImage: "person.2")
                } else {
                    List(records) { record in
                        NavigationLink {
                            SharedRecordDetailView(record: record) { isLiked in
                                await toggleLike(for: record, isLiked: isLiked)
                            }
                        } label: {
                            SharedRecordRowView(record: record)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Share")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            friendSheet = .myCode
                        } label: {
                            Label("マイコード", systemImage: "qrcode")
                        }

                        Button {
                            friendSheet = .addFriend
                        } label: {
                            Label("友達登録", systemImage: "person.badge.plus")
                        }

                        Button {
                            friendSheet = .friends
                        } label: {
                            Label("友達一覧", systemImage: "person.2")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await loadRecords()
            }
            .task {
                await loadRecords()
            }
            .alert("読み込みエラー", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(item: $friendSheet) { sheet in
                NavigationStack {
                    switch sheet {
                    case .myCode:
                        ShareMyCodeView()
                    case .addFriend:
                        ShareFriendRegistrationView()
                    case .friends:
                        ShareFriendListView()
                    }
                }
            }
        }
    }

    @MainActor
    private func loadRecords() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            records = try await service.fetchSharedRecords()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func toggleLike(for record: SharedCleaningRecord, isLiked: Bool) async {
        do {
            try await service.toggleLike(recordID: record.id, isLikedByCurrentUser: isLiked)
            records = try await service.fetchSharedRecords()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ShareMyCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileViewModel = UserProfileViewModel()
    private let qrContext = CIContext()
    private let qrFilter = CIFilter.qrCodeGenerator()

    var body: some View {
        Form {
            Section("マイコード") {
                VStack(spacing: 14) {
                    if profileViewModel.accountCode.isEmpty {
                        ProgressView()
                    } else {
                        qrCodeImage(for: profileViewModel.accountCode)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 190, height: 190)

                        Text(profileViewModel.accountCode)
                            .font(.system(size: 30, weight: .bold, design: .monospaced))
                            .textSelection(.enabled)

                        Text("このQRコードを友達に読み取ってもらうと、友達登録できます。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
        }
        .navigationTitle("マイコード")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("閉じる") {
                    dismiss()
                }
            }
        }
        .task {
            await profileViewModel.load()
            await profileViewModel.prepareAccountCodeIfNeeded()
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

private struct ShareFriendRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileViewModel = UserProfileViewModel()
    @State private var isShowingQRScanner = false
    @State private var isShowingFriendAddedAlert = false
    @FocusState private var isFriendCodeFocused: Bool

    var body: some View {
        Form {
            Section("友達登録") {
                TextField("友達のアカウントコード", text: $profileViewModel.friendCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($isFriendCodeFocused)

                Button {
                    isFriendCodeFocused = false
                    isShowingQRScanner = true
                } label: {
                    Label("QRコードを読み取る", systemImage: "qrcode.viewfinder")
                        .frame(maxWidth: .infinity)
                }
            }

            Section {
                Button {
                    isFriendCodeFocused = false
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
                .buttonStyle(SharePrimaryButtonStyle())
                .disabled(profileViewModel.isAddingFriend || profileViewModel.friendCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

            if let errorMessage = profileViewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle("友達登録")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("閉じる") {
                    dismiss()
                }
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
}

private struct ShareFriendListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileViewModel = UserProfileViewModel()

    var body: some View {
        Group {
            if profileViewModel.isLoading {
                ProgressView()
            } else {
                List {
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

                    if let errorMessage = profileViewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("友達一覧")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("閉じる") {
                    dismiss()
                }
            }
        }
        .task {
            await profileViewModel.load()
            await profileViewModel.refreshFriends()
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
}

private struct SharedRecordRowView: View {
    let record: SharedCleaningRecord

    var body: some View {
        HStack(spacing: 12) {
            profileIcon

            VStack(alignment: .leading, spacing: 4) {
                Text(record.ownerName)
                    .font(.headline)
                Text("掃除時間 \(String(format: "%.2f", record.elapsedTime)) 秒")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("\(record.likeCount)", systemImage: record.isLikedByCurrentUser ? "heart.fill" : "heart")
                    .font(.caption)
                    .foregroundStyle(record.isLikedByCurrentUser ? .red : .secondary)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var profileIcon: some View {
        if let url = record.ownerIconURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .frame(width: 48, height: 48)
        }
    }
}

private struct SharePrimaryButtonStyle: ButtonStyle {
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

private struct SharedRecordDetailView: View {
    let record: SharedCleaningRecord
    var onLikeTapped: (Bool) async -> Void
    @State private var isUpdatingLike = false
    @State private var displayedLikeCount: Int
    @State private var displayedIsLiked: Bool

    init(record: SharedCleaningRecord, onLikeTapped: @escaping (Bool) async -> Void) {
        self.record = record
        self.onLikeTapped = onLikeTapped
        self._displayedLikeCount = State(initialValue: record.likeCount)
        self._displayedIsLiked = State(initialValue: record.isLikedByCurrentUser)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    profileIcon
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.ownerName)
                            .font(.title3.weight(.bold))
                        Text(record.createdAt.formatted(date: .complete, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(String(format: "%.2f 秒", record.elapsedTime))
                    .font(.system(size: 46, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(alignment: .top, spacing: 14) {
                    sharedImageView(title: "Before", url: record.beforeImageURL)
                    sharedImageView(title: "After", url: record.afterImageURL)
                }

                scoreSection
                playedTracksSection

                Button {
                    Task {
                        isUpdatingLike = true
                        let wasLiked = displayedIsLiked
                        displayedIsLiked.toggle()
                        displayedLikeCount += wasLiked ? -1 : 1
                        await onLikeTapped(wasLiked)
                        isUpdatingLike = false
                    }
                } label: {
                    Label(
                        "\(displayedLikeCount)",
                        systemImage: displayedIsLiked ? "heart.fill" : "heart"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(LikeButtonStyle(isLiked: displayedIsLiked))
                .disabled(isUpdatingLike)
            }
            .padding()
        }
        .navigationTitle("共有記録")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var profileIcon: some View {
        if let url = record.ownerIconURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 54, height: 54)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .frame(width: 54, height: 54)
        }
    }

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Gemini評価")
                .font(.headline)
            if let beforeScore = record.beforeTidinessScore {
                Text("片付け前: \(beforeScore) 点")
            }
            if let afterScore = record.afterTidinessScore {
                Text("片付け後: \(afterScore) 点")
            }
            if let improvementScore = record.improvementScore {
                Text("改善度: \(improvementScore > 0 ? "+" : "")\(improvementScore)点")
            }
            if record.beforeTidinessScore == nil,
               record.afterTidinessScore == nil,
               record.improvementScore == nil {
                Text("評価はありません")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var playedTracksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("再生した曲")
                .font(.headline)

            if record.playedTracks.isEmpty {
                Text("曲がありません")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(record.playedTracks) { track in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .fontWeight(.semibold)
                        if !track.artistName.isEmpty {
                            Text(track.artistName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func sharedImageView(title: String, url: URL?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            if let url {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 180)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LikeButtonStyle: ButtonStyle {
    let isLiked: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(isLiked ? .white : .red)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(isLiked ? Color.red : Color.red.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

#Preview {
    ShareView()
}
