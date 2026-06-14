import SwiftUI

struct CleaningSessionFlowView: View {
    private enum Phase {
        case beforeCamera
        case cleaning
        case afterCamera
        case result
    }

    let playbackSource: PlaybackSource
    let initialSecondsElapsed: Double
    let isResumeMode: Bool
    let initialBeforeImage: UIImage?
    var onFinishFlow: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?
    @State private var resultSecondsElapsed: Double
    @State private var playedTracks: [PlayedTrackInfo] = []
    @State private var phase: Phase

    init(
        playbackSource: PlaybackSource,
        initialBeforeImage: UIImage? = nil,
        initialSecondsElapsed: Double = 0,
        isResumeMode: Bool = false,
        onFinishFlow: @escaping () -> Void
    ) {
        self.playbackSource = playbackSource
        self.initialBeforeImage = initialBeforeImage
        self.initialSecondsElapsed = initialSecondsElapsed
        self.isResumeMode = isResumeMode
        self.onFinishFlow = onFinishFlow
        self._beforeImage = State(initialValue: initialBeforeImage)
        self._afterImage = State(initialValue: nil)
        self._resultSecondsElapsed = State(initialValue: initialSecondsElapsed)
        self._phase = State(initialValue: initialBeforeImage == nil ? .beforeCamera : .cleaning)
    }

    var body: some View {
        Group {
            switch phase {
            case .beforeCamera:
                beforeCameraView
            case .cleaning:
                cleaningView
            case .afterCamera:
                afterCameraView
            case .result:
                resultView
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private var beforeCameraView: some View {
        CameraPickerView(
            onImagePicked: handleBeforeImagePicked,
            onCancel: { dismiss() }
        )
        .ignoresSafeArea()
    }

    private var cleaningView: some View {
        CleaningView(
            beforeImage: $beforeImage,
            afterImage: $afterImage,
            playbackSource: playbackSource,
            initialSecondsElapsed: initialSecondsElapsed,
            isResumeMode: isResumeMode,
            onCompleteCleaning: completeCleaning
        ) {
            onFinishFlow()
            dismiss()
        }
    }

    private var afterCameraView: some View {
        CameraPickerView(
            onImagePicked: handleAfterImagePicked,
            onCancel: { phase = .cleaning }
        )
        .ignoresSafeArea()
    }

    private var resultView: some View {
        ResultView(
            resultTimer: resultSecondsElapsed,
            beforeImage: $beforeImage,
            afterImage: $afterImage,
            playedTracks: playedTracks
        ) {
            onFinishFlow()
            dismiss()
        }
    }

    private func handleBeforeImagePicked(_ image: UIImage?) {
        guard let image else {
            dismiss()
            return
        }
        beforeImage = image
        afterImage = nil
        phase = .cleaning
    }

    private func handleAfterImagePicked(_ image: UIImage?) {
        guard let image else {
            phase = .cleaning
            return
        }
        afterImage = image
        phase = .result
    }

    private func completeCleaning(secondsElapsed: Double, playedTracks: [PlayedTrackInfo]) {
        resultSecondsElapsed = secondsElapsed
        self.playedTracks = playedTracks
        afterImage = nil
        phase = .afterCamera
    }
}
