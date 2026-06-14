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
    var onFinishFlow: () -> Void
    @Environment(\.modelContext) private var context
    @State private var timer: Timer!
    @State private var secondsElapsed: Double
    @State private var isRunning = false
    @State private var isSongPrepared: Bool
    @State private var isShowAlert = false
    @State private var isShowResult = false
    
    init(
        beforeImage: Binding<UIImage?>,
        afterImage: Binding<UIImage?>,
        playbackSource: PlaybackSource,
        initialSecondsElapsed: Double = 0,
        isResumeMode: Bool = false,
        onFinishFlow: @escaping () -> Void
    ) {
        self._beforeImage = beforeImage
        self._afterImage = afterImage
        self.playbackSource = playbackSource
        self.initialSecondsElapsed = initialSecondsElapsed
        self.isResumeMode = isResumeMode
        self.onFinishFlow = onFinishFlow
        self._secondsElapsed = State(initialValue: initialSecondsElapsed)
        self._isSongPrepared = State(initialValue: isResumeMode)
    }
    
    
    var body: some View {
        
        NavigationStack {
            VStack {
                Text(String(format: "%.2f",secondsElapsed)).font(.title)
                HStack {
                    if isRunning {
                        Button{
                            pause()
                        } label: {
                            Image(systemName: "pause.fill")
                                .foregroundColor(.white)
                                .font(.title)
                                .padding()
                                .background(Color.orange)
                                .clipShape(.circle)
                            
                        }
                        
                    }else{
                        Button{
                            start()
                        } label: {
                            Image(systemName: "play.fill")
                                .foregroundColor(.white)
                                .font(.title)
                                .padding()
                                .background(Color.green)
                                .clipShape(.circle)
                        }
                    }
                    if secondsElapsed != 0.0{
                        Button{
                            stop()
                        } label: {
                            Image(systemName: "stop.fill")
                                .foregroundColor(.white)
                                .font(.title)
                                .padding()
                                .background(Color.red)
                                .clipShape(.circle)
                        }
                    }
                    
                }
                Button("仮保存") {
                    isShowAlert.toggle()
                }
                .alert("仮保存しますか", isPresented: $isShowAlert) {
                    Button("戻る"){}
                    Button("仮保存する"){
                        saveDraft()
                        pause()
                        onFinishFlow()
                    }
                }
                Button("完了") {
                    stop()
                    isShowResult = true
                }
            }
            
            //.navigationDestination(isPresented: $isShowResult){
            //PhotoafterView()
            .navigationDestination(isPresented: $isShowResult) {
                PhotoafterView(
                    secondsElapsed: secondsElapsed,
                    beforeImage: $beforeImage,
                    afterImage: $afterImage,
                    onFinishFlow: onFinishFlow
                )
            }

            
            }
            .onAppear {
                print("[CleaningView] onAppear. before image exists: \(beforeImage != nil)")
                if isResumeMode {
                    isSongPrepared = true
                }
            }
            
        }
    
    //                NavigationLink("", isActive: $isShowResult) {
    //                    ResultView()
    //                }
    
    func start() {
        print("[CleaningView] start timer")
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {_ in secondsElapsed += 0.1}
        isRunning = true
        playOrResumeSelectedSong()
    }
    
    func pause() {
        print("[CleaningView] pause timer at \(secondsElapsed)")
        timer.invalidate()
        isRunning = false
        pauseSelectedSong()
    }
    
    func stop() {
        print("[CleaningView] stop timer at \(secondsElapsed)")
        timer.invalidate()
        isRunning = false
        stopSelectedSong()
        isSongPrepared = false
        let saveTime: Double
        saveTime = secondsElapsed
        UserDefaults.standard.set(saveTime, forKey: "saki-chan")
        
        secondsElapsed = 0.0
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
        case .local(let items):
            guard !items.isEmpty else {
                print("[CleaningView] no local tracks available")
                return
            }
            let player = MPMusicPlayerController.applicationQueuePlayer
            player.setQueue(with: MPMediaItemCollection(items: items))
            player.repeatMode = .all
            player.play()
        }
    }

    @MainActor
    private func resumePlayback() async {
        switch playbackSource {
        case .appleMusic:
            try? await ApplicationMusicPlayer.shared.play()
        case .local:
            MPMusicPlayerController.applicationQueuePlayer.play()
        }
    }
}
