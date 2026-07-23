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
                VStack(alignment: .leading, spacing: 32) {
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
                    
                    Text("My PlayList")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(.top, 20)

                    if viewModel.canPlayCatalogContent {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 24) {
                                if viewModel.appleMusicPlaylists.isEmpty {
                                    playlistPlaceholderCard(title: "Empty Playlist", subtitle: "")
                                } else {
                                    ForEach(Array(viewModel.appleMusicPlaylists)) { playlist in
                                        NavigationLink {
                                            PhotobeforeView(
                                                beforeImage: $beforeImage,
                                                afterImage: $afterImage,
                                                playbackSource: .appleMusic(Array(playlist.tracks ?? []))
                                            )
                                        } label: {
                                            appleMusicPlaylistCard(for: playlist)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.trailing, 24)
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 24) {
                                if viewModel.localPlaylists.isEmpty {
                                    playlistPlaceholderCard(title: "Empty Playlist", subtitle: "")
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
                                            localPlaylistCard(for: playlist, playlistName: playlistName)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.trailing, 24)
                        }
                    }

                    VStack(spacing: 28) {
                        moodCard(
                            title: "Relaxing",
                            systemImage: "leaf.fill",
                            imageColor: Color(red: 126 / 255, green: 203 / 255, blue: 86 / 255),
                            backgroundColor: Color(red: 190 / 255, green: 226 / 255, blue: 207 / 255)
                        )

                        moodCard(
                            title: "Hardcore",
                            systemImage: "sun.max.fill",
                            imageColor: Color(red: 1, green: 110 / 255, blue: 36 / 255),
                            backgroundColor: Color(red: 250 / 255, green: 200 / 255, blue: 170 / 255)
                        )
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
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
            }
            .background(homeBackground)
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

    private func appleMusicPlaylistCard(for playlist: Playlist) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            playlistArtwork(for: playlist)
            Text(playlist.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text("\(playlist.tracks?.count ?? 0)曲")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func localPlaylistCard(for playlist: MPMediaPlaylist, playlistName: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            localPlaylistArtwork(for: playlist)
            Text(playlistName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text("\(playlist.count)曲")
                .font(.caption)
                .foregroundStyle(.secondary)
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

    private func playlistPlaceholderCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            playlistArtworkPlaceholder
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

    private func moodCard(
        title: String,
        systemImage: String,
        imageColor: Color,
        backgroundColor: Color
    ) -> some View {
        Button {
        } label: {
            VStack(alignment: .leading, spacing: 28) {
                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.primary)

                HStack(alignment: .bottom) {
                    Image(systemName: systemImage)
                        .font(.system(size: 62, weight: .regular))
                        .foregroundStyle(imageColor)
                    Spacer()
                    Text(">>>")
                        .font(.system(size: 42, weight: .regular))
                        .foregroundStyle(.primary)
                        .padding(.bottom, 2)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var homeBackground: Color {
        Color(red: 253 / 255, green: 253 / 255, blue: 250 / 255)
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
