import UIKit

enum CleaningFlowCompletionAction {
    case none
    case clearLatestDraft
}

struct CleaningFlowPresentation: Identifiable {
    let id = UUID()
    let playbackSource: PlaybackSource
    let initialBeforeImage: UIImage?
    let initialSecondsElapsed: Double
    let isResumeMode: Bool
    let completionAction: CleaningFlowCompletionAction
}
