//
//  CleaningView.swift
//  Kataduke
//
//  Created by Saki on 2025/12/21.
//

import SwiftUI
import MusicKit
import SwiftData
import MediaPlayer

struct CleaningView: View{
    
    @Binding var beforeImage: UIImage?
    @Binding var afterImage: UIImage?
    let playbackSource: PlaybackSource
    let initialSecondsElapsed: Double
    let isResumeMode: Bool
    var onCompleteCleaning: (Double, [PlayedTrackInfo]) -> Void
    var onFinishFlow: () -> Void
    @Environment(\.modelContext) private var context
    @State private var timer: Timer?
    @State private var secondsElapsed: Double
    @State private var isRunning = false
    @State private var isSongPrepared: Bool
    @State private var isShowAlert = false
    @State private var volume: Double = 0.58
    @State private var playedTracks: [PlayedTrackInfo] = []
    @State private var playedTrackIDs: Set<String> = []
    
    init(
        beforeImage: Binding<UIImage?>,
        afterImage: Binding<UIImage?>,
        playbackSource: PlaybackSource,
        initialSecondsElapsed: Double = 0,
        isResumeMode: Bool = false,
        onCompleteCleaning: @escaping (Double, [PlayedTrackInfo]) -> Void,
        onFinishFlow: @escaping () -> Void
    ) {
        self._beforeImage = beforeImage
        self._afterImage = afterImage
        self.playbackSource = playbackSource
        self.initialSecondsElapsed = initialSecondsElapsed
        self.isResumeMode = isResumeMode
        self.onCompleteCleaning = onCompleteCleaning
        self.onFinishFlow = onFinishFlow
        self._secondsElapsed = State(initialValue: initialSecondsElapsed)
        self._isSongPrepared = State(initialValue: isResumeMode)
    }
    
    
    var body: some View {
        
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        pause()
                        onFinishFlow()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 34, weight: .regular))
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                }
                .padding(.top, 10)
                .padding(.horizontal, 26)

                Spacer(minLength: 8)

                VStack(spacing: 4) {
                    Text(currentTrackTitle)
                        .font(.system(size: 23, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    if let artistName = currentTrackArtistName {
                        Text(artistName)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 34)

                timerRing
                    .padding(.top, 10)

                Spacer(minLength: 18)

                HStack(spacing: 38) {
                    Button {
                        skipToPrevious()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.primary)
                    }

                    Button {
                        isRunning ? pause() : start()
                    } label: {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 70, height: 70)
                            .background(cleaningOrange)
                            .clipShape(Circle())
                    }

                    Button {
                        skipToNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)

                volumeControl
                    .padding(.top, 20)
                    .padding(.horizontal, 44)

                VStack(spacing: 14) {
                    Button("仮保存") {
                        isShowAlert.toggle()
                    }
                    .buttonStyle(CleaningPrimaryButtonStyle())
                    .alert("仮保存しますか", isPresented: $isShowAlert) {
                        Button("戻る"){}
                        Button("仮保存する"){
                            saveDraft()
                            pause()
                            onFinishFlow()
                        }
                    }

                    Button("完了") {
                        let completedSecondsElapsed = secondsElapsed
                        stop(resetElapsed: false)
                        onCompleteCleaning(completedSecondsElapsed, playedTracks)
                    }
                    .buttonStyle(CleaningPrimaryButtonStyle())
                }
                .padding(.top, 18)
                .padding(.horizontal, 44)
                .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(cleaningBackground)
            .navigationBarBackButtonHidden(true)
        }
            .onAppear {
                print("[CleaningView] onAppear. before image exists: \(beforeImage != nil)")
                if isResumeMode {
                    isSongPrepared = true
                }
            }
        }
    
    private var timerRing: some View {
        ZStack {
            Circle()
                .fill(Color(red: 213 / 255, green: 213 / 255, blue: 213 / 255))
                .frame(width: 210, height: 210)

            Circle()
                .stroke(Color(red: 207 / 255, green: 208 / 255, blue: 216 / 255), lineWidth: 9)
                .frame(width: 238, height: 238)

            Circle()
                .trim(from: 0, to: timerProgress)
                .stroke(cleaningOrange, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .frame(width: 238, height: 238)
                .rotationEffect(.degrees(-90))

            Text(String(format: "%.2f", secondsElapsed))
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(.primary)
        }
        .frame(width: 250, height: 250)
    }

    private var volumeControl: some View {
        HStack(spacing: 14) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 19, weight: .semibold))
            Slider(value: $volume, in: 0...1)
                .tint(.primary)
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 21, weight: .semibold))
        }
        .foregroundStyle(.primary)
    }

    private var timerProgress: Double {
        let minutes = secondsElapsed.truncatingRemainder(dividingBy: 60)
        return max(0.04, min(minutes / 60, 1))
    }

    private var cleaningOrange: Color {
        Color(red: 239 / 255, green: 132 / 255, blue: 69 / 255)
    }

    private var cleaningBackground: Color {
        Color(red: 253 / 255, green: 253 / 255, blue: 250 / 255)
    }

    func start() {
        print("[CleaningView] start timer")
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            secondsElapsed += 0.1
            recordCurrentTrack()
        }
        isRunning = true
        playOrResumeSelectedSong()
    }
    
    func pause() {
        print("[CleaningView] pause timer at \(secondsElapsed)")
        timer?.invalidate()
        isRunning = false
        pauseSelectedSong()
    }
    
    func stop(resetElapsed: Bool = true) {
        print("[CleaningView] stop timer at \(secondsElapsed)")
        timer?.invalidate()
        isRunning = false
        stopSelectedSong()
        isSongPrepared = false
        if resetElapsed {
            secondsElapsed = 0.0
        }
    }
    
    @MainActor
    private func playOrResumeSelectedSong() {
        Task {
            do {
                if isSongPrepared {
                    await resumePlayback()
                    print("[CleaningView] resumed playback")
                } else {
                    await startPlayback()
                    isSongPrepared = true
                    print("[CleaningView] started playback")
                }
            } catch {
                print("[CleaningView] failed to play selected song: \(error)")
            }
        }
    }
    
    private func stopSelectedSong() {
        switch playbackSource {
        case .appleMusic:
            ApplicationMusicPlayer.shared.stop()
        case .local:
            MPMusicPlayerController.applicationQueuePlayer.stop()
        }
    }
    
    private func pauseSelectedSong() {
        switch playbackSource {
        case .appleMusic:
            ApplicationMusicPlayer.shared.pause()
        case .local:
            MPMusicPlayerController.applicationQueuePlayer.pause()
        }
    }

    private func skipToNext() {
        switch playbackSource {
        case .appleMusic:
            Task { try? await ApplicationMusicPlayer.shared.skipToNextEntry() }
        case .local:
            MPMusicPlayerController.applicationQueuePlayer.skipToNextItem()
        }
    }

    private func skipToPrevious() {
        switch playbackSource {
        case .appleMusic:
            Task { try? await ApplicationMusicPlayer.shared.skipToPreviousEntry() }
        case .local:
            MPMusicPlayerController.applicationQueuePlayer.skipToPreviousItem()
        }
    }
    
    private func saveDraft() {
        let beforeImageData = beforeImage?.jpegData(compressionQuality: 0.8)
        let existingDrafts = (try? context.fetch(FetchDescriptor<DraftCleaningSession>())) ?? []
        for draft in existingDrafts {
            context.delete(draft)
        }
        
        let fallbackSongID: String
        let fallbackTitle: String
        let fallbackArtist: String
        switch playbackSource {
        case .appleMusic(let tracks):
            let fallbackSong = tracks.first
            fallbackSongID = fallbackSong?.id.rawValue ?? ""
            fallbackTitle = fallbackSong?.title ?? "Playlist"
            fallbackArtist = fallbackSong?.artistName ?? ""
        case .local(let items):
            let fallbackSong = items.first
            fallbackSongID = String(fallbackSong?.persistentID ?? 0)
            fallbackTitle = fallbackSong?.title ?? "Library"
            fallbackArtist = fallbackSong?.artist ?? ""
        }
        
        let draft = DraftCleaningSession(
            elapsedTime: secondsElapsed,
            songIDRawValue: fallbackSongID,
            songTitle: fallbackTitle,
            songArtistName: fallbackArtist,
            beforeImageData: beforeImageData
        )
        context.insert(draft)
        print("[CleaningView] draft saved")
    }

    @MainActor
    private func startPlayback() async {
        switch playbackSource {
        case .appleMusic(let tracks):
            guard !tracks.isEmpty else {
                print("[CleaningView] no Apple Music tracks available")
                return
            }
            let player = ApplicationMusicPlayer.shared
            player.queue = .init(for: tracks)
            try? await player.play()
            recordCurrentTrack()
        case .local(let items):
            guard !items.isEmpty else {
                print("[CleaningView] no local tracks available")
                return
            }
            let player = MPMusicPlayerController.applicationQueuePlayer
            player.setQueue(with: MPMediaItemCollection(items: items))
            player.repeatMode = .all
            player.play()
            recordCurrentTrack()
        }
    }

    @MainActor
    private func resumePlayback() async {
        switch playbackSource {
        case .appleMusic:
            try? await ApplicationMusicPlayer.shared.play()
            recordCurrentTrack()
        case .local:
            MPMusicPlayerController.applicationQueuePlayer.play()
            recordCurrentTrack()
        }
    }

    private func recordCurrentTrack() {
        switch playbackSource {
        case .appleMusic:
            recordAppleMusicTrack()
        case .local:
            recordLocalTrack()
        }
    }

    private func recordAppleMusicTrack() {
        guard let track = ApplicationMusicPlayer.shared.queue.currentEntry?.item as? Track else {
            return
        }
        appendPlayedTrackIfNeeded(
            PlayedTrackInfo(
                id: track.id.rawValue,
                title: track.title,
                artistName: track.artistName
            )
        )
    }

    private func recordLocalTrack() {
        guard let item = MPMusicPlayerController.applicationQueuePlayer.nowPlayingItem else {
            return
        }
        appendPlayedTrackIfNeeded(
            PlayedTrackInfo(
                id: String(item.persistentID),
                title: item.title ?? "Unknown",
                artistName: item.artist ?? ""
            )
        )
    }

    private func appendPlayedTrackIfNeeded(_ track: PlayedTrackInfo) {
        guard playedTrackIDs.contains(track.id) == false else { return }
        playedTrackIDs.insert(track.id)
        playedTracks.append(track)
    }

    private var currentTrackTitle: String {
        switch playbackSource {
        case .appleMusic(let tracks):
            return tracks.first?.title ?? "曲名がありません"
        case .local(let items):
            return items.first?.title ?? "曲名がありません"
        }
    }

    private var currentTrackArtistName: String? {
        switch playbackSource {
        case .appleMusic(let tracks):
            return tracks.first?.artistName
        case .local(let items):
            return items.first?.artist
        }
    }
}

private struct CleaningPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(red: 239 / 255, green: 132 / 255, blue: 69 / 255))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
