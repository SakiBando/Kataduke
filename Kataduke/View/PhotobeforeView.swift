////
////  PhotobeforeView.swift
////  Kataduke
////
////  Created by Saki on 2026/01/12.
////
import SwiftUI

struct PhotobeforeView: View {
    @Binding var beforeImage: UIImage?
    @Binding var afterImage: UIImage?
    let playbackSource: PlaybackSource
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CleaningSessionFlowView(playbackSource: playbackSource) {
            beforeImage = nil
            afterImage = nil
            dismiss()
        }
            .toolbar(.hidden, for: .tabBar)
    }
}
