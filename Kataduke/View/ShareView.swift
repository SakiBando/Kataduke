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
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("友達の記録")
            .background(shareBackground)
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
            errorMessage = readableShareErrorMessage(from: error)
        }
    }

    @MainActor
    private func toggleLike(for record: SharedCleaningRecord, isLiked: Bool) async {
        do {
            try await service.toggleLike(recordID: record.id, isLikedByCurrentUser: isLiked)
            records = try await service.fetchSharedRecords()
        } catch {
            errorMessage = readableShareErrorMessage(from: error)
        }
    }

    private func readableShareErrorMessage(from error: Error) -> String {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("permission") {
            return "共有記録を読み込む権限がありません。追加した firestore.rules を Firebase に反映してください。"
        }
        return message
    }
}

private struct ShareSheetContainer<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: systemImage)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(shareMint)
                            .frame(width: 58, height: 58)
                            .background(Circle().fill(Color.white.opacity(0.86)))
                            .shadow(color: shareMint.opacity(0.14), radius: 10, x: 0, y: 6)

                        Text(title)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(shareText)
                    }

                    Spacer()

                    Button("閉じる") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(shareMint)
                }

                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 36)
        }
        .background(shareBackground.ignoresSafeArea())
    }
}

private struct ShareMyCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileViewModel = UserProfileViewModel()
    private let qrContext = CIContext()
    private let qrFilter = CIFilter.qrCodeGenerator()

    var body: some View {
        ShareSheetContainer(title: "マイコード", systemImage: "qrcode") {
            VStack(spacing: 14) {
                if profileViewModel.accountCode.isEmpty {
                    ProgressView()
                        .tint(shareMint)
                        .frame(height: 220)
                } else {
                    qrCodeImage(for: profileViewModel.accountCode)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 190, height: 190)
                        .padding(18)
                        .background(Color.white.opacity(0.88))
                        .clipShape(RoundedRectangle(cornerRadius: 24))

                    Text(profileViewModel.accountCode)
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .foregroundStyle(shareText)
                        .textSelection(.enabled)

                    Text("このQRコードを友達に読み取ってもらうと、友達登録できます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(22)
            .background(Color.white.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(shareMint.opacity(0.20), lineWidth: 1))
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
        ShareSheetContainer(title: "友達登録", systemImage: "person.badge.plus") {
            VStack(alignment: .leading, spacing: 16) {
                TextField("友達のアカウントコード", text: $profileViewModel.friendCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($isFriendCodeFocused)
                    .padding(14)
                    .background(Color.white.opacity(0.86))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(shareMint.opacity(0.20), lineWidth: 1))

                Button {
                    isFriendCodeFocused = false
                    isShowingQRScanner = true
                } label: {
                    Label("QRコードを読み取る", systemImage: "qrcode.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ShareSoftButtonStyle())

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

                if let errorMessage = profileViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
            .padding(18)
            .background(Color.white.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(shareMint.opacity(0.20), lineWidth: 1))
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
        ShareSheetContainer(title: "友達一覧", systemImage: "person.2") {
            VStack(spacing: 12) {
                if profileViewModel.isLoading {
                    ProgressView()
                        .tint(shareMint)
                        .frame(height: 120)
                } else if profileViewModel.friends.isEmpty {
                    Text("まだ友達がいません")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(Color.white.opacity(0.82))
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                } else {
                    ForEach(profileViewModel.friends) { friend in
                        HStack(spacing: 12) {
                            friendIcon(url: friend.iconURL)
                            Text(friend.name)
                                .font(.headline)
                                .foregroundStyle(shareText)
                            Spacer()
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.82))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(shareMint.opacity(0.18), lineWidth: 1))
                    }
                }

                if let errorMessage = profileViewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
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
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(shareText)
                Text(shareDateTimeText(record.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text("総時間 \(shareFormattedDuration(record.elapsedTime))")
                    .font(.subheadline)
                    .foregroundStyle(shareMint)
                .lineLimit(1)
                Label("\(record.likeCount)", systemImage: record.isLikedByCurrentUser ? "heart.fill" : "heart")
                    .font(.caption)
                    .foregroundStyle(record.isLikedByCurrentUser ? .red : .secondary)
            }
            Spacer()
            if let improvementScore = record.improvementScore {
                Text("\(improvementScore > 0 ? "+" : "")\(improvementScore)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(shareYellow)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(shareMint.opacity(0.18), lineWidth: 1))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .padding(.vertical, 4)
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
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: [
                        shareMint,
                        Color(red: 126 / 255, green: 190 / 255, blue: 174 / 255)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: shareMint.opacity(configuration.isPressed ? 0.12 : 0.26), radius: 10, x: 0, y: 6)
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

private struct ShareSoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(shareMint)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.white.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(shareMint.opacity(0.24), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

private struct SharedRecordDetailView: View {
    let record: SharedCleaningRecord
    var onLikeTapped: (Bool) async -> Void
    @State private var isUpdatingLike = false
    @State private var displayedLikeCount: Int
    @State private var displayedIsLiked: Bool
    @State private var isShowingPlayedSongsSheet = false

    init(record: SharedCleaningRecord, onLikeTapped: @escaping (Bool) async -> Void) {
        self.record = record
        self.onLikeTapped = onLikeTapped
        self._displayedLikeCount = State(initialValue: record.likeCount)
        self._displayedIsLiked = State(initialValue: record.isLikedByCurrentUser)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    profileIcon
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.ownerName)
                            .font(.system(size: 20, weight: .bold))
                        Text(shareDateTimeText(record.createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("総時間 \(shareFormattedDuration(record.elapsedTime))")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(shareMint)
                .lineLimit(1)

                HStack(alignment: .top, spacing: 14) {
                    sharedImageView(title: "Before", url: record.beforeImageURL)
                    sharedImageView(title: "After", url: record.afterImageURL)
                }

                HStack(alignment: .top, spacing: 14) {
                    playedTracksSection
                    scoreSection
                }

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
            .frame(width: min(geometry.size.width - 32, 390), alignment: .center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            }
        }
        .background(shareBackground)
        .navigationTitle("共有記録")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingPlayedSongsSheet) {
            PlayedSongsSheet(tracks: record.playedTracks, tintColor: shareMint)
                .presentationDetents([.medium, .large])
        }
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

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Score", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(shareMint)
            if let beforeScore = record.beforeTidinessScore {
                shareScoreLine("Before", beforeScore, color: .secondary)
            }
            if let afterScore = record.afterTidinessScore {
                shareScoreLine("After", afterScore, color: shareMint)
            }
            if let improvementScore = record.improvementScore {
                Text("\(improvementScore > 0 ? "+" : "")\(improvementScore)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(shareYellow)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            if record.beforeTidinessScore == nil,
               record.afterTidinessScore == nil,
               record.improvementScore == nil {
                Text("評価はありません")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 220, alignment: .topLeading)
        .padding(12)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(shareMint.opacity(0.22), lineWidth: 1))
    }

    private var playedTracksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Played songs", systemImage: "music.note")
                .font(.headline)
                .foregroundStyle(shareMint)

            if record.playedTracks.isEmpty {
                Text("曲がありません")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(record.playedTracks.prefix(3)) { track in
                    PlayedSongRow(track: track, tintColor: shareMint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if record.playedTracks.count > 3 {
                    Button {
                        isShowingPlayedSongsSheet = true
                    } label: {
                        Text("もっと見る")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(shareMint)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 220, alignment: .topLeading)
        .padding(12)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(shareMint.opacity(0.22), lineWidth: 1))
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
                .frame(height: 162)
                .clipShape(RoundedRectangle(cornerRadius: 22))
            } else {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.82))
                    .frame(height: 162)
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

private let shareMint = Color(red: 69 / 255, green: 166 / 255, blue: 145 / 255)
private let shareYellow = Color(red: 244 / 255, green: 185 / 255, blue: 70 / 255)
private let shareText = Color(red: 40 / 255, green: 68 / 255, blue: 66 / 255)
private let shareBackground = Color(red: 253 / 255, green: 251 / 255, blue: 245 / 255)

private func shareFormattedDuration(_ seconds: Double) -> String {
    let totalSeconds = max(0, Int(seconds.rounded(.down)))
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

private func shareDateTimeText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.dateFormat = "yyyy/MM/dd・HH:mm"
    return formatter.string(from: date)
}

private func shareScoreLine(_ title: String, _ score: Int, color: Color) -> some View {
    HStack {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
        Spacer()
        Text("\(score)")
            .font(.title3.weight(.bold))
            .foregroundStyle(color)
    }
}

#Preview {
    ShareView()
}
