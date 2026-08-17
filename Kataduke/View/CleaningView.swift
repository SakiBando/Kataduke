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
    var onSaveDraftFlow: () -> Void
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
    @State private var currentPlayedTrack: PlayedTrackInfo?
    @State private var lastTrackRefreshSecond = -1
    
    init(
        beforeImage: Binding<UIImage?>,
        afterImage: Binding<UIImage?>,
        playbackSource: PlaybackSource,
        initialSecondsElapsed: Double = 0,
        isResumeMode: Bool = false,
        onCompleteCleaning: @escaping (Double, [PlayedTrackInfo]) -> Void,
        onSaveDraftFlow: @escaping () -> Void,
        onFinishFlow: @escaping () -> Void
    ) {
        self._beforeImage = beforeImage
        self._afterImage = afterImage
        self.playbackSource = playbackSource
        self.initialSecondsElapsed = initialSecondsElapsed
        self.isResumeMode = isResumeMode
        self.onCompleteCleaning = onCompleteCleaning
        self.onSaveDraftFlow = onSaveDraftFlow
        self.onFinishFlow = onFinishFlow
        self._secondsElapsed = State(initialValue: initialSecondsElapsed)
        self._isSongPrepared = State(initialValue: isResumeMode)
    }
    
    
    var body: some View {
        
        NavigationStack {
            ZStack {
                cleaningBackground
                    .ignoresSafeArea()

                decorativeBackground

                GeometryReader { geometry in
                    let compactness = cleaningLayoutScale(for: geometry.size.height)
                    let ringSize = cleaningRingSize(for: geometry.size)
                    let isCompactHeight = geometry.size.height < 780

                    VStack(spacing: 0) {
                    if isCompactHeight == false {
                        headerBar
                            .scaleEffect(compactness)
                            .padding(.top, 8)
                            .padding(.horizontal, 22)
                    }

                    VStack(spacing: isCompactHeight ? 2 : 6) {
                        Text("Cleaning")
                            .font(.system(size: isCompactHeight ? 22 : 24, weight: .bold))
                            .foregroundStyle(cleaningMint)

                        Text(currentTrackTitle)
                            .font(.system(size: isCompactHeight ? 27 : 33, weight: .heavy))
                            .foregroundStyle(cleaningText)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)

                        if let artistName = currentTrackArtistName, artistName.isEmpty == false {
                            Text(artistName)
                                .font(.system(size: isCompactHeight ? 19 : 22, weight: .semibold))
                                .foregroundStyle(cleaningMint)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }

                        playlistChip
                            .scaleEffect(compactness)
                            .padding(.top, isCompactHeight ? 0 : 4)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, isCompactHeight ? 0 : 10)

                    timerRing(size: ringSize)
                        .padding(.top, isCompactHeight ? 12 : 22)

                    playbackControls
                        .scaleEffect(compactness)
                        .padding(.top, isCompactHeight ? 14 : 22)

                    volumeControl
                        .scaleEffect(compactness)
                        .padding(.top, isCompactHeight ? 10 : 20)
                        .padding(.horizontal, 46)

                    Spacer(minLength: isCompactHeight ? 8 : 16)

                    actionButtons
                        .scaleEffect(compactness)
                        .padding(.horizontal, 28)
                        .padding(.bottom, isCompactHeight ? 10 : 20)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationBarBackButtonHidden(true)
        }
            .onAppear {
                print("[CleaningView] onAppear. before image exists: \(beforeImage != nil)")
                if isResumeMode {
                    isSongPrepared = true
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
        }
    
    private func timerRing(size: CGFloat) -> some View {
        let outerSize = size
        let innerSize = size * 0.76
        let strokeWidth = max(10, size * 0.043)
        let motifWidth = size * 0.49
        let motifHeight = size * 0.39

        return ZStack {
            Circle()
                .stroke(cleaningMint.opacity(0.25), lineWidth: strokeWidth)
                .frame(width: outerSize, height: outerSize)
                .shadow(color: cleaningMint.opacity(0.18), radius: 10, x: 0, y: 8)

            Circle()
                .trim(from: 0, to: timerProgress)
                .stroke(cleaningOrange, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: outerSize, height: outerSize)
                .rotationEffect(.degrees(-84))

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            cleaningMint.opacity(0.34),
                            cleaningMint.opacity(0.18),
                            Color.white.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: innerSize, height: innerSize)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.88), lineWidth: 10)
                )
                .shadow(color: cleaningMint.opacity(0.18), radius: 18, x: 0, y: 12)

            VStack(spacing: 12) {
                appIconMotif
                    .frame(width: motifWidth, height: motifHeight)

                StopwatchTimeText(secondsElapsed: secondsElapsed)
                    .foregroundStyle(cleaningMint)
                    .frame(width: size * 0.68)
            }
        }
        .frame(width: size + 28, height: size + 28)
    }

    private var volumeControl: some View {
        HStack(spacing: 14) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 20, weight: .semibold))
            Slider(value: $volume, in: 0...1)
                .tint(cleaningMint)
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 22, weight: .semibold))
        }
        .foregroundStyle(cleaningMint)
    }

    private var headerBar: some View {
        HStack {
            Button {
                pause()
                onFinishFlow()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(cleaningMint)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(.white.opacity(0.76)))
                    .shadow(color: cleaningMint.opacity(0.16), radius: 10, x: 0, y: 6)
            }

            Spacer()

            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(cleaningMint)
                .frame(width: 58, height: 58)
                .background(Circle().fill(.white.opacity(0.76)))
                .shadow(color: cleaningMint.opacity(0.16), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var playlistChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "leaf.fill")
            Text(cleaningModeName)
        }
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(cleaningMint)
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(cleaningMint.opacity(0.08))
                .overlay(Capsule().stroke(cleaningMint.opacity(0.25), lineWidth: 1.5))
        )
    }

    private var playbackControls: some View {
        HStack(spacing: 42) {
            Button {
                skipToPrevious()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(cleaningMint)
                    .frame(width: 68, height: 68)
                    .background(Circle().fill(.white.opacity(0.72)))
                    .overlay(Circle().stroke(cleaningMint.opacity(0.18), lineWidth: 1.5))
                    .shadow(color: cleaningMint.opacity(0.16), radius: 10, x: 0, y: 8)
            }

            Button {
                isRunning ? pause() : start()
            } label: {
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
                    .background(
                        Circle()
                            .fill(cleaningMint)
                            .shadow(color: cleaningMint.opacity(0.28), radius: 14, x: 0, y: 10)
                    )
            }

            Button {
                skipToNext()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(cleaningMint)
                    .frame(width: 68, height: 68)
                    .background(Circle().fill(.white.opacity(0.72)))
                    .overlay(Circle().stroke(cleaningMint.opacity(0.18), lineWidth: 1.5))
                    .shadow(color: cleaningMint.opacity(0.16), radius: 10, x: 0, y: 8)
            }
        }
        .buttonStyle(.plain)
    }

    private var actionButtons: some View {
        HStack(spacing: 14) {
            Button {
                isShowAlert.toggle()
            } label: {
                Label("仮保存", systemImage: "bookmark.fill")
            }
            .buttonStyle(CleaningSecondaryButtonStyle(mint: cleaningMint))
            .alert("仮保存しますか", isPresented: $isShowAlert) {
                Button("戻る"){}
                Button("仮保存する"){
                    saveDraft()
                    pause()
                    onSaveDraftFlow()
                }
            }

            Button {
                let completedSecondsElapsed = secondsElapsed
                stop(resetElapsed: false)
                onCompleteCleaning(completedSecondsElapsed, playedTracks)
            } label: {
                Text("完了")
            }
            .buttonStyle(CleaningPrimaryButtonStyle())
        }
    }

    private var appIconMotif: some View {
        ZStack(alignment: .bottom) {
            Image(systemName: "house")
                .font(.system(size: 92, weight: .light))
                .foregroundStyle(.white.opacity(0.92))
                .offset(y: 8)

            Image(systemName: "music.note")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white.opacity(0.95))
                .offset(x: 10, y: -24)

            Image(systemName: "leaf.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(cleaningMint.opacity(0.78))
                .rotationEffect(.degrees(-18))
                .offset(x: -38, y: -8)

            Image(systemName: "folder.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(cleaningYellow.opacity(0.88))
                .rotationEffect(.degrees(9))
                .offset(x: 42, y: 2)

        }
    }

    private var decorativeBackground: some View {
        ZStack {
            Color.clear

            Image(systemName: "leaf.fill")
                .font(.system(size: 34))
                .foregroundStyle(cleaningMint.opacity(0.45))
                .rotationEffect(.degrees(24))
                .offset(x: 118, y: -282)

            Image(systemName: "leaf.fill")
                .font(.system(size: 54))
                .foregroundStyle(cleaningMint.opacity(0.22))
                .rotationEffect(.degrees(-24))
                .offset(x: -166, y: 330)

            Image(systemName: "folder.fill")
                .font(.system(size: 82))
                .foregroundStyle(cleaningYellow.opacity(0.48))
                .rotationEffect(.degrees(-12))
                .offset(x: 182, y: 374)
        }
        .allowsHitTesting(false)
    }

    private var timerProgress: Double {
        let minutes = secondsElapsed.truncatingRemainder(dividingBy: 60)
        return min(minutes / 60, 1)
    }

    private func cleaningLayoutScale(for height: CGFloat) -> CGFloat {
        min(1, max(0.76, height / 860))
    }

    private func cleaningRingSize(for size: CGSize) -> CGFloat {
        let heightBasedSize = size.height * 0.31
        let widthBasedSize = size.width * 0.66
        return min(252, max(206, min(heightBasedSize, widthBasedSize)))
    }

    private var cleaningModeName: String {
        switch playbackSource {
        case .appleMusic:
            return "Relaxing"
        case .local:
            return "Relaxing"
        }
    }

    private var cleaningMint: Color {
        Color(red: 113 / 255, green: 177 / 255, blue: 161 / 255)
    }

    private var cleaningYellow: Color {
        Color(red: 244 / 255, green: 195 / 255, blue: 91 / 255)
    }

    private var cleaningOrange: Color {
        Color(red: 239 / 255, green: 132 / 255, blue: 69 / 255)
    }

    private var cleaningText: Color {
        Color(red: 40 / 255, green: 68 / 255, blue: 66 / 255)
    }

    private var cleaningBackground: Color {
        Color(red: 253 / 255, green: 251 / 255, blue: 245 / 255)
    }

    func start() {
        print("[CleaningView] start timer")
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                secondsElapsed += 1
                refreshCurrentTrackIfNeeded()
            }
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
            Task {
                try? await ApplicationMusicPlayer.shared.skipToNextEntry()
                await updateCurrentTrackDisplayAfterSkip()
            }
        case .local:
            MPMusicPlayerController.applicationQueuePlayer.skipToNextItem()
            updateCurrentTrackDisplayAfterLocalSkip()
        }
    }

    private func skipToPrevious() {
        switch playbackSource {
        case .appleMusic:
            Task {
                try? await ApplicationMusicPlayer.shared.skipToPreviousEntry()
                await updateCurrentTrackDisplayAfterSkip()
            }
        case .local:
            MPMusicPlayerController.applicationQueuePlayer.skipToPreviousItem()
            updateCurrentTrackDisplayAfterLocalSkip()
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
            updateCurrentTrackDisplay()
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
            updateCurrentTrackDisplay()
        }
    }

    @MainActor
    private func resumePlayback() async {
        switch playbackSource {
        case .appleMusic:
            try? await ApplicationMusicPlayer.shared.play()
            recordCurrentTrack()
            updateCurrentTrackDisplay()
        case .local:
            MPMusicPlayerController.applicationQueuePlayer.play()
            recordCurrentTrack()
            updateCurrentTrackDisplay()
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

    @MainActor
    private func refreshCurrentTrackIfNeeded() {
        let wholeSecond = Int(secondsElapsed.rounded(.down))
        guard wholeSecond != lastTrackRefreshSecond else { return }
        lastTrackRefreshSecond = wholeSecond
        recordCurrentTrack()
        updateCurrentTrackDisplay()
    }

    @MainActor
    private func updateCurrentTrackDisplay() {
        currentPlayedTrack = currentPlaybackTrackInfo()
    }

    @MainActor
    private func updateCurrentTrackDisplayAfterSkip() async {
        try? await Task.sleep(nanoseconds: 300_000_000)
        recordCurrentTrack()
        updateCurrentTrackDisplay()
    }

    private func updateCurrentTrackDisplayAfterLocalSkip() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            recordCurrentTrack()
            updateCurrentTrackDisplay()
        }
    }

    private func currentPlaybackTrackInfo() -> PlayedTrackInfo? {
        switch playbackSource {
        case .appleMusic:
            guard let track = ApplicationMusicPlayer.shared.queue.currentEntry?.item as? Track else {
                return nil
            }
            return PlayedTrackInfo(
                id: track.id.rawValue,
                title: track.title,
                artistName: track.artistName
            )
        case .local:
            guard let item = MPMusicPlayerController.applicationQueuePlayer.nowPlayingItem else {
                return nil
            }
            return PlayedTrackInfo(
                id: String(item.persistentID),
                title: item.title ?? "Unknown",
                artistName: item.artist ?? ""
            )
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
        currentPlayedTrack = track
        guard playedTrackIDs.contains(track.id) == false else { return }
        playedTrackIDs.insert(track.id)
        playedTracks.append(track)
    }

    private var currentTrackTitle: String {
        if let currentPlayedTrack {
            return currentPlayedTrack.title
        }
        switch playbackSource {
        case .appleMusic(let tracks):
            return tracks.first?.title ?? "曲名がありません"
        case .local(let items):
            return items.first?.title ?? "曲名がありません"
        }
    }

    private var currentTrackArtistName: String? {
        if let currentPlayedTrack {
            return currentPlayedTrack.artistName
        }
        switch playbackSource {
        case .appleMusic(let tracks):
            return tracks.first?.artistName
        case .local(let items):
            return items.first?.artist
        }
    }

}

private struct StopwatchTimeText: View {
    let secondsElapsed: Double

    var body: some View {
        Text(timeText)
            .font(.system(size: secondsElapsed >= 3600 ? 28 : 43, weight: .bold, design: .monospaced))
            .minimumScaleFactor(0.72)
            .lineLimit(1)
            .frame(width: 205)
    }

    private var timeText: String {
        let totalSeconds = max(0, Int(secondsElapsed.rounded(.down)))
        let seconds = totalSeconds % 60
        let minutes = (totalSeconds / 60) % 60
        if totalSeconds >= 3600 {
            let hours = totalSeconds / 3600
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct CleaningPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 19, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(red: 244 / 255, green: 195 / 255, blue: 91 / 255))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.7), lineWidth: 1)
                    )
                    .shadow(color: Color(red: 244 / 255, green: 195 / 255, blue: 91 / 255).opacity(0.28), radius: 12, x: 0, y: 8)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct CleaningSecondaryButtonStyle: ButtonStyle {
    let mint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(mint)
            .labelStyle(.titleAndIcon)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.white.opacity(0.78))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(mint.opacity(0.34), lineWidth: 1.5)
                    )
                    .shadow(color: mint.opacity(0.14), radius: 10, x: 0, y: 8)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
