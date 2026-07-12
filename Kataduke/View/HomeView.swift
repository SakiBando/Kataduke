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
                    let allPlaylistSongs = viewModel.appleMusicPlaylists.flatMap { Array($0.tracks ?? []) }
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
                            CleaningSessionFlowView(
                                playbackSource: playbackSource,
                                initialBeforeImage: resumeBeforeImageData.flatMap(UIImage.init(data:)),
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
                                if viewModel.appleMusicPlaylists.isEmpty {
                                    Text("Empty Playlist")
                                } else {
                                    ForEach(Array(viewModel.appleMusicPlaylists)) { playlist in
                                        NavigationLink {
                                            PhotobeforeView(
                                                beforeImage: $beforeImage,
                                                afterImage: $afterImage,
                                                playbackSource: .appleMusic(Array(playlist.tracks ?? []))
                                            )
                                        } label: {
                                            VStack(alignment: .leading, spacing: 8) {
                                                playlistArtwork(for: playlist)
                                                Text(playlist.name)
                                                    .font(.headline)
                                                    .foregroundStyle(.primary)
                                                    .frame(width: 150, alignment: .leading)
                                                    .lineLimit(2)
                                                Text("\(playlist.tracks?.count ?? 0)曲")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
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
                                            VStack(alignment: .leading, spacing: 8) {
                                                localPlaylistArtwork(for: playlist)
                                                Text(playlistName)
                                                    .font(.headline)
                                                    .foregroundStyle(.primary)
                                                    .frame(width: 150, alignment: .leading)
                                                    .lineLimit(2)
                                                Text("\(playlist.count)曲")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
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
                            await viewModel.fetchAppleMusicPlaylists()
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

    @ViewBuilder
    private func playlistArtwork(for playlist: Playlist) -> some View {
        if let artworkURL = playlist.artwork?.url(width: 300, height: 300) {
            AsyncImage(url: artworkURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 150, height: 150)
            .background(Color.gray.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            ZStack {
                Color.gray.opacity(0.12)
                Image(systemName: "music.note.list")
                    .font(.system(size: 42))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 150, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder
    private func localPlaylistArtwork(for playlist: MPMediaPlaylist) -> some View {
        if let artwork = playlist.representativeItem?.artwork,
           let image = artwork.image(at: CGSize(width: 300, height: 300)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 150, height: 150)
                .background(Color.gray.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            playlistArtworkPlaceholder
        }
    }

    private var playlistArtworkPlaceholder: some View {
        ZStack {
            Color.gray.opacity(0.12)
            Image(systemName: "music.note.list")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
        }
        .frame(width: 150, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
