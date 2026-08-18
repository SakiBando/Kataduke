//
//  ResultView.swift
//  Kataduke
//
//  Created by Saki on 2025/12/21.
//

import SwiftUI
import SwiftData
import Foundation
import PhotosUI



struct ResultView: View {
    @State var resultTimer: Double
    @Binding var beforeImage: UIImage?
    @Binding var afterImage: UIImage?
    let playedTracks: [PlayedTrackInfo]
    var onFinishFlow: () -> Void
    @Environment(\.modelContext) var context
    @State private var evaluation: CleanupEvaluation?
    @State private var isEvaluating = false
    @State private var isSaving = false
    @State private var evaluationError: String?
    @State private var saveError: String?
    private let sharedRecordService = SharedCleaningRecordService()

    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Button {
                            onFinishFlow()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 30, weight: .regular))
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)

                        VStack(spacing: 8) {
                            Image(systemName: "house")
                                .font(.system(size: 34, weight: .light))
                                .foregroundStyle(resultMint)
                            HStack(spacing: 8) {
                                Image(systemName: "leaf.fill")
                                Text("Today’s Cleaning")
                                Image(systemName: "leaf.fill")
                            }
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(resultMint)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, -4)

                        Text(formattedDuration(resultTimer))
                            .font(.system(size: 68, weight: .bold, design: .rounded))
                            .foregroundStyle(resultMint)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, -8)

                        HStack(alignment: .top, spacing: 12) {
                            resultImageView(image: beforeImage, title: "Before")
                            resultImageView(image: afterImage, title: "After")
                        }

                        HStack(alignment: .top, spacing: 12) {
                            playedTracksSection
                            evaluationSection
                        }

                        VStack(spacing: 14) {
                            Button {
                                Task { await saveImage(shouldShare: true) }
                            } label: {
                                if isSaving {
                                    ProgressView()
                                } else {
                                    Label("Share & Save", systemImage: "square.and.arrow.up")
                                }
                            }
                            .buttonStyle(ResultPrimaryButtonStyle())
                            .disabled(isSaving)

                            Button {
                                Task { await saveImage(shouldShare: false) }
                            } label: {
                                if isSaving {
                                    ProgressView()
                                } else {
                                    Text("Save only")
                                }
                            }
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(resultMint)
                            .disabled(isSaving)
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 18)
                        .padding(.bottom, 24)

                        if let saveError {
                            Text(saveError)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .frame(width: min(geometry.size.width - 28, 390), alignment: .center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)
                }
            }
            .background(resultBackground)
            .navigationBarBackButtonHidden(true)
            .task {
                await evaluateCleanupIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var playedTracksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Played songs", systemImage: "music.note")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(resultMint)

            if playedTracks.isEmpty {
                Text("曲がありません")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(playedTracks.prefix(2)) { track in
                    HStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(resultMint)
                            .frame(width: 34, height: 34)
                            .background(resultMint.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            if !track.artistName.isEmpty {
                                Text(track.artistName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 196, alignment: .topLeading)
        .padding(12)
        .background(resultCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(resultMint.opacity(0.28), lineWidth: 1))
    }
    
    private func scoreRow(title: String, score: Int) -> some View {
            HStack {
                Spacer()
                Text(title == "改善度" && score > 0 ? "+\(score) 点" : "\(score) 点")
                    .fontWeight(.semibold)
            }
        }
    
    @ViewBuilder
    private var evaluationSection: some View {
            VStack(alignment: .leading, spacing: 12) {
                Label("Score", systemImage: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(resultMint)
                
                if isEvaluating {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("片付け度を採点中...")
                            .foregroundStyle(.secondary)
                    }
                } else if let evaluation {
                    VStack(spacing: 10) {
                        resultScoreLine("Before", evaluation.clampedBeforeScore, color: .secondary)
                        Divider()
                        resultScoreLine("After", evaluation.clampedAfterScore, color: resultMint)
                        Divider()
                        Text("+\(evaluation.improvementScore)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(resultYellow)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else if let evaluationError {
                    Text(evaluationError)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 196, alignment: .topLeading)
            .padding(12)
            .background(resultCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(resultMint.opacity(0.28), lineWidth: 1))
        }

    private func resultScoreLine(_ title: String, _ score: Int, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
            Spacer()
            Text("\(score)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }
    
    @ViewBuilder
    func resultImageView(image: UIImage?, title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 170)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 22))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(resultCardBackground)
                    .frame(height: 170)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    
    @MainActor
    func saveImage(shouldShare: Bool) async {
        guard beforeImage != nil || afterImage != nil else {
            print("images not found")
            return
        }
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        let beforeImageData = beforeImage?.jpegData(compressionQuality: 0.8)
        let afterImageData = afterImage?.jpegData(compressionQuality: 0.8)
        let playedTracksData = try? JSONEncoder().encode(playedTracks)
        var sharedRecordID: String?

        if shouldShare {
            do {
                sharedRecordID = try await sharedRecordService.shareRecord(
                    elapsedTime: resultTimer,
                    beforeImage: beforeImage,
                    afterImage: afterImage,
                    playedTracks: playedTracks,
                    beforeTidinessScore: evaluation?.clampedBeforeScore,
                    afterTidinessScore: evaluation?.clampedAfterScore,
                    improvementScore: evaluation?.improvementScore
                )
            } catch {
                saveError = error.localizedDescription
                return
            }
        }

        let record = SelectedImage(
            elapsedTime: resultTimer,
            beforeImageData: beforeImageData,
            afterImageData: afterImageData,
            playedTracksData: playedTracksData,
            beforeTidinessScore: evaluation?.clampedBeforeScore,
            afterTidinessScore: evaluation?.clampedAfterScore,
            improvementScore: evaluation?.improvementScore,
            sharedRecordID: sharedRecordID
        )
        context.insert(record)
        
        print("[ResultView] save complete. Returning HomeView")
        onFinishFlow()
    }
    
    private var resultBackground: Color {
        Color(red: 253 / 255, green: 253 / 255, blue: 250 / 255)
    }

    private var resultCardBackground: Color {
        Color.white.opacity(0.82)
    }

    private var resultMint: Color {
        Color(red: 69 / 255, green: 166 / 255, blue: 145 / 255)
    }

    private var resultYellow: Color {
        Color(red: 244 / 255, green: 185 / 255, blue: 70 / 255)
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    @MainActor
    private func evaluateCleanupIfNeeded() async {
        guard evaluation == nil, evaluationError == nil, !isEvaluating else { return }
        guard let beforeImage, let afterImage else {
            print("[ResultView] evaluation skipped because images are missing")
            return
        }
        
        isEvaluating = true
        defer { isEvaluating = false }
        
        do {
            evaluation = try await CleanupEvaluationService.evaluate(
                before: beforeImage,
                after: afterImage,
                elapsedTime: resultTimer
            )
            print("[ResultView] evaluation finished: \(String(describing: evaluation))")
        } catch {
            evaluationError = error.localizedDescription
            print("[ResultView] evaluation failed: \(error.localizedDescription)")
        }
    }
}

private struct ResultPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color(red: 218 / 255, green: 143 / 255, blue: 24 / 255))
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 255 / 255, green: 244 / 255, blue: 213 / 255),
                        Color(red: 247 / 255, green: 198 / 255, blue: 91 / 255).opacity(0.55)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color(red: 244 / 255, green: 185 / 255, blue: 70 / 255), lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
