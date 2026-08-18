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
    @State private var moodPlaybackSource: PlaybackSource?
    @State private var isShowingMoodCleaning = false
    @State private var subscriptionAlertMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
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
                                isResumeMode: true,
                                onSaveDraftFlow: {
                                    isShowingResume = false
                                }
                            ) {
                                clearDraft()
                                isShowingResume = false
                            }
                        }
                    }
                    
                    homeHeader
                        .padding(.top, 24)

                    HStack {
                        Text("My Playlist")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(homeMint)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(homeMint)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.white.opacity(0.82)))
                            .shadow(color: homeMint.opacity(0.14), radius: 9, x: 0, y: 6)
                    }
                    .padding(.top, 18)

                    if viewModel.canPlayCatalogContent {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 16) {
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
                            LazyHStack(alignment: .top, spacing: 16) {
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

                    HStack(spacing: 16) {
                        moodCard(
                            title: "Relaxing",
                            systemImage: "chair.lounge.fill",
                            accentImage: "music.note",
                            imageColor: homeMint,
                            backgroundColors: [
                                homeMint.opacity(0.18),
                                Color.white.opacity(0.88)
                            ],
                            searchTerm: "リラックス"
                        )

                        moodCard(
                            title: "Uptempo",
                            systemImage: "paintbrush.pointed.fill",
                            accentImage: "music.note",
                            imageColor: homeYellow,
                            backgroundColors: [
                                homeYellow.opacity(0.30),
                                Color.white.opacity(0.92)
                            ],
                            searchTerm: "集中"
                        )
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 110)
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
            .fullScreenCover(isPresented: $isShowingMoodCleaning) {
                if let moodPlaybackSource {
                    CleaningSessionFlowView(playbackSource: moodPlaybackSource) {
                        self.moodPlaybackSource = nil
                        isShowingMoodCleaning = false
                    }
                }
            }
            .alert("Apple Music", isPresented: Binding(
                get: { subscriptionAlertMessage != nil },
                set: { if !$0 { subscriptionAlertMessage = nil } }
            )) {
                Button("OK") { subscriptionAlertMessage = nil }
            } message: {
                Text(subscriptionAlertMessage ?? "")
            }
        }
    }

    private var homeHeader: some View {
        HStack(alignment: .center) {
            Text("Kataduke")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(homeMint)
                .shadow(color: .white.opacity(0.9), radius: 1, x: 0, y: 1)

            Image(systemName: "leaf.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(homeMint)
                .offset(x: -3, y: -15)

            Spacer()

            Image(systemName: "music.note")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(homeMint)
                .frame(width: 56, height: 56)
                .background(Circle().fill(.white.opacity(0.86)))
                .shadow(color: homeMint.opacity(0.16), radius: 12, x: 0, y: 8)
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
            AsyncImage(url: artworkURL) { phase in
                switch phase {
                case .empty:
                    playlistArtworkLoading
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    playlistArtworkPlaceholderContent
                @unknown default:
                    playlistArtworkPlaceholderContent
                }
            }
            .frame(width: 150, height: 150)
            .background(playlistCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            playlistArtworkPlaceholderContent
            .frame(width: 150, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func appleMusicPlaylistCard(for playlist: Playlist) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            playlistArtwork(for: playlist)
            Text(playlist.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(homeText)
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
                .foregroundStyle(homeText)
                .lineLimit(1)
            Text("\(playlist.count)曲")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func localPlaylistArtwork(for playlist: MPMediaPlaylist) -> some View {
        if let artwork = playlist.items.compactMap(\.artwork).first,
           let image = artwork.image(at: CGSize(width: 300, height: 300)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 150, height: 150)
                .background(playlistCardBackground)
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
                .foregroundStyle(homeText)
                .lineLimit(1)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var playlistArtworkPlaceholder: some View {
        playlistArtworkPlaceholderContent
            .frame(width: 150, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var playlistArtworkPlaceholderContent: some View {
        ZStack {
            playlistCardBackground
            Image(systemName: "music.note")
                .font(.system(size: 42))
                .foregroundStyle(.black)
        }
    }

    private var playlistArtworkLoading: some View {
        ZStack {
            playlistCardBackground
            ProgressView()
                .tint(homeMint)
        }
    }

    private func moodCard(
        title: String,
        systemImage: String,
        accentImage: String,
        imageColor: Color,
        backgroundColors: [Color],
        searchTerm: String
    ) -> some View {
        Button {
            Task {
                await startMoodCleaning(searchTerm: searchTerm)
            }
        } label: {
            VStack(spacing: 22) {
                ZStack {
                    Image(systemName: systemImage)
                        .font(.system(size: 68, weight: .regular))
                        .foregroundStyle(imageColor.opacity(0.92))
                        .offset(y: 8)

                    Image(systemName: accentImage)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(imageColor.opacity(0.65))
                        .offset(x: 42, y: -42)

                    if viewModel.isLoadingMoodPlaylist {
                        ProgressView()
                            .offset(x: 48, y: 48)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 104)

                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(imageColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .frame(height: 252)
            .background(
                LinearGradient(
                    colors: backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(.white.opacity(0.82), lineWidth: 3)
            )
            .shadow(color: imageColor.opacity(0.18), radius: 12, x: 0, y: 8)
        }
        .disabled(viewModel.isLoadingMoodPlaylist)
        .buttonStyle(.plain)
    }

    private var homeBackground: Color {
        Color(red: 246 / 255, green: 252 / 255, blue: 247 / 255)
    }

    private var homeMint: Color {
        Color(red: 113 / 255, green: 177 / 255, blue: 161 / 255)
    }

    private var homeYellow: Color {
        Color(red: 218 / 255, green: 160 / 255, blue: 56 / 255)
    }

    private var homeText: Color {
        Color(red: 40 / 255, green: 68 / 255, blue: 66 / 255)
    }

    private var playlistCardBackground: Color {
        Color(red: 214 / 255, green: 214 / 255, blue: 214 / 255)
    }

    @MainActor
    private func startMoodCleaning(searchTerm: String) async {
        let tracks = await viewModel.fetchMoodPlaylistTracks(searchTerm: searchTerm)
        guard !tracks.isEmpty else {
            subscriptionAlertMessage = viewModel.moodPlaylistErrorMessage ?? "Apple Musicに登録してください。"
            return
        }
        moodPlaybackSource = .appleMusic(tracks)
        isShowingMoodCleaning = true
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
