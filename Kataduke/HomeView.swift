import Foundation
import SwiftUI
import MusicKit
import SwiftData
import MediaPlayer

struct HomeView: View {
    @StateObject private var viewModel = MusicViewModel(musicService: MusicServiceImpl())
    @State private var activeFlowPresentation: CleaningFlowPresentation?
    @Environment(\.modelContext) private var context
    @Query(sort: \DraftCleaningSession.updatedAt, order: .reverse) private var draftSessions: [DraftCleaningSession]
    
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
                            activeFlowPresentation = CleaningFlowPresentation(
                                playbackSource: playbackSource,
                                initialBeforeImage: draft.beforeImageData.flatMap(UIImage.init(data:)),
                                initialSecondsElapsed: draft.elapsedTime,
                                isResumeMode: true,
                                completionAction: .clearLatestDraft
                            )
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
                                        Button {
                                            activeFlowPresentation = CleaningFlowPresentation(
                                                playbackSource: .appleMusic(Array(playlist.tracks ?? [])),
                                                initialBeforeImage: nil,
                                                initialSecondsElapsed: 0,
                                                isResumeMode: false,
                                                completionAction: .none
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
                                        Button {
                                            activeFlowPresentation = CleaningFlowPresentation(
                                                playbackSource: .local(playlist.items),
                                                initialBeforeImage: nil,
                                                initialSecondsElapsed: 0,
                                                isResumeMode: false,
                                                completionAction: .none
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
                .fullScreenCover(item: $activeFlowPresentation, onDismiss: clearActiveFlowPresentation) { presentation in
                    CleaningSessionFlowView(
                        playbackSource: presentation.playbackSource,
                        initialBeforeImage: presentation.initialBeforeImage,
                        initialSecondsElapsed: presentation.initialSecondsElapsed,
                        isResumeMode: presentation.isResumeMode
                    ) {
                        handleFlowFinished(action: presentation.completionAction)
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
        if let draft = draftSessions.first {
            context.delete(draft)
            print("[HomeView] draft cleared")
        }
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

    private func clearActiveFlowPresentation() {
        activeFlowPresentation = nil
    }

    private func handleFlowFinished(action: CleaningFlowCompletionAction) {
        switch action {
        case .none:
            break
        case .clearLatestDraft:
            clearDraft()
        }
    }
}
#Preview {
    HomeView()
}
