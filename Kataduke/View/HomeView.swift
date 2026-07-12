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
                    let allLocalPlaylistSongs = viewModel.localPlaylists.flatMap { $0.items }
                    let resumeAppleSong = draftSessions.first.flatMap { draft in
                        allPlaylistSongs.first(where: { $0.id.rawValue == draft.songIDRawValue })
                    }
                    let resumeLocalSong = draftSessions.first.flatMap { draft in
                        allLocalPlaylistSongs.first(where: { String($0.persistentID) == draft.songIDRawValue })
                    }
                    
                    if let draft = draftSessions.first,
                       let playbackSource = resumePlaybackSource(
                        draft: draft,
                        appleSong: resumeAppleSong,
                        localSong: resumeLocalSong
                       ) {
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
                                playbackSource: playbackSource,
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
                        Text("ローカルプレイリスト")
                            .font(.headline)
                        ScrollView(.horizontal) {
                            LazyHStack(alignment: .top) {
                                if viewModel.localPlaylists.isEmpty {
                                    Text("Empty Playlist")
                                } else {
                                    ForEach(viewModel.localPlaylists, id: \.persistentID) { playlist in
                                        NavigationLink {
                                            PhotobeforeView(
                                                beforeImage: $beforeImage,
                                                afterImage: $afterImage,
                                                playbackSource: .local(playlist.items)
                                            )
                                        } label: {
                                            let playlistName = {
                                                guard let name = playlist.name, !name.isEmpty else {
                                                    return "Unknown Playlist"
                                                }
                                                return name
                                            }()
                                            VStack(alignment: .leading) {
                                                Text(playlistName)
                                                    .font(.headline)
                                                    .frame(width: 100)
                                                    .lineLimit(1)
                                                Text("\(playlist.count)曲")
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
                            await viewModel.fetchRecommendedPlaylists()
                        } else {
                            await viewModel.fetchLocalPlaylists()
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

    private func resumePlaybackSource(
        draft: DraftCleaningSession,
        appleSong: Track?,
        localSong: MPMediaItem?
    ) -> PlaybackSource? {
        if let appleSong {
            return .appleMusic([appleSong])
        }
        if let localSong {
            return .local([localSong])
        }
        print("[HomeView] no matching draft song found for \(draft.songIDRawValue)")
        return nil
    }
}
#Preview {
    HomeView()
}
