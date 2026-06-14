import Foundation
import SwiftUI
import MusicKit
import SwiftData
import MediaPlayer

struct HomeView: View {
    @StateObject private var viewModel = MusicViewModel(musicService: MusicServiceImpl())
    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?
    @Environment(\.modelContext) private var context
    @Query(sort: \DraftCleaningSession.updatedAt, order: .reverse) private var draftSessions: [DraftCleaningSession]
    @State private var resumeDraft: DraftCleaningSession?
    @State private var resumeBeforeImageData: Data?
    @State private var isShowingResume = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    let allPlaylistSongs = viewModel.recommendedPlayLisits.flatMap { Array($0.tracks ?? []) }
                    
                    if let draft = draftSessions.first,
                       let song = allPlaylistSongs.first(where: { $0.id.rawValue == draft.songIDRawValue }) {
                        Button {
                            resumeDraft = draft
                            resumeBeforeImageData = draft.beforeImageData
                            beforeImage = draft.beforeImageData.flatMap(UIImage.init(data:))
                            afterImage = nil
                            isShowingResume = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("再開")
                                        .font(.headline)
                                    Text(draft.songTitle)
                                        .font(.subheadline)
                                    Text(draft.songArtistName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "play.fill")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .fullScreenCover(isPresented: $isShowingResume) {
                            CleaningView(
                                beforeImage: $beforeImage,
                                afterImage: $afterImage,
                                playbackSource: .appleMusic([song]),
                                initialSecondsElapsed: resumeDraft?.elapsedTime ?? 0,
                                isResumeMode: true
                            ) {
                                clearDraft()
                                isShowingResume = false
                            }
                        }
                    }
                    
                    if viewModel.canPlayCatalogContent {
                        Text("プレイリスト一覧")
                            .font(.headline)
                        ScrollView(.horizontal) {
                            LazyHStack(alignment: .top) {
                                if viewModel.recommendedPlayLisits.isEmpty {
                                    Text("Empty Playlist")
                                } else {
                                    ForEach(Array(viewModel.recommendedPlayLisits)) { playlist in
                                        NavigationLink {
                                            PhotobeforeView(
                                                beforeImage: $beforeImage,
                                                afterImage: $afterImage,
                                                playbackSource: .appleMusic(Array(playlist.tracks ?? []))
                                            )
                                        } label: {
                                            VStack(alignment: .leading) {
                                                VStack(alignment: .leading) {
                                                    Text(playlist.name)
                                                        .font(.headline)
                                                        .frame(width: 100)
                                                        .lineLimit(1)
                                                    Text("プレイリスト")
                                                        .font(.caption)
                                                }
                                            }
                                            .padding(.horizontal, 5)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding()
                        }
                    } else {
                        Text("ローカルライブラリ")
                            .font(.headline)
                        ScrollView(.horizontal) {
                            LazyHStack(alignment: .top) {
                                if viewModel.localSongs.isEmpty {
                                    Text("Empty Library")
                                } else {
                                    ForEach(viewModel.localSongs, id: \.persistentID) { item in
                                        NavigationLink {
                                            PhotobeforeView(
                                                beforeImage: $beforeImage,
                                                afterImage: $afterImage,
                                                playbackSource: .local([item])
                                            )
                                        } label: {
                                            VStack(alignment: .leading) {
                                                Text(item.title ?? "Unknown")
                                                    .font(.headline)
                                                    .frame(width: 100)
                                                    .lineLimit(1)
                                                Text(item.artist ?? "")
                                                    .font(.caption)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
    //                Text(viewModel.recommendedPlayLisits.first?.name ?? "ありません")
                }
                .onAppear() {
                    Task {
                        await viewModel.authorize()
                        let canPlayCatalogContent = await viewModel.fetchSubscriptionStatus()
                        if canPlayCatalogContent {
                            try await viewModel.fetchRecommendedPlaylists()
                        } else {
                            await viewModel.fetchLocalSongs()
                        }
                    }
                }
                Button{
                    
                } label: {
                    Text("ゆったり")
                        .font(.system(size: 38))
                        .foregroundStyle(.black)
                        .frame(width:300, height: 100)
                        .background(Color(red: 183 / 255, green: 169 / 255, blue: 154 / 255))
                        .cornerRadius(12)
                }
                Button{
                    
                } label: {
                    Text("がっつり")
                        .font(.system(size: 38))
                        .foregroundStyle(.black)
                        .frame(width:300, height: 100)
                        .background(Color(red: 215 / 255, green: 184 / 255, blue: 163 / 255))
                        .cornerRadius(12)
                }
            }
        }
    }

    private func clearDraft() {
        if let draft = resumeDraft ?? draftSessions.first {
            context.delete(draft)
            print("[HomeView] draft cleared")
        }
        resumeDraft = nil
        resumeBeforeImageData = nil
    }
}
#Preview {
    HomeView()
}
