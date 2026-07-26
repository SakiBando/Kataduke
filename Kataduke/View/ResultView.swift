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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Button {
                        onFinishFlow()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 32, weight: .regular))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)

                    Text(String(format: "%.2f", resultTimer))
                        .font(.system(size: 78, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, -8)

                    HStack(alignment: .top, spacing: 18) {
                        resultImageView(image: beforeImage, title: "Before")
                        resultImageView(image: afterImage, title: "After")
                    }

                    evaluationSection
                    playedTracksSection

                    VStack(spacing: 22) {
                        Button {
                            Task { await saveImage(shouldShare: true) }
                        } label: {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("共有して保存")
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
                                Text("共有せずに保存")
                            }
                        }
                        .buttonStyle(ResultPrimaryButtonStyle())
                        .disabled(isSaving)
                    }
                    .padding(.horizontal, 70)
                    .padding(.top, 28)
                    .padding(.bottom, 24)

                    if let saveError {
                        Text(saveError)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(resultBackground)
            .navigationBarBackButtonHidden(true)
            .onAppear() {
                fetchTimer()
            }
            .task {
                await evaluateCleanupIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var playedTracksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("再生した曲")
                .font(.system(size: 30, weight: .bold))

            if playedTracks.isEmpty {
                Text("曲がありません")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(playedTracks.prefix(2)) { track in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 24, weight: .semibold))
                            .lineLimit(1)
                        if !track.artistName.isEmpty {
                            Text(track.artistName)
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 156, alignment: .topLeading)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(resultCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                Text("Gemini評価")
                    .font(.system(size: 30, weight: .bold))
                
                if isEvaluating {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("片付け度を採点中...")
                            .foregroundStyle(.secondary)
                    }
                } else if let evaluation {
                    VStack(alignment: .trailing, spacing: 12) {
                        scoreRow(title: "片付け前", score: evaluation.clampedBeforeScore)
                        scoreRow(title: "片付け後", score: evaluation.clampedAfterScore)
                        scoreRow(title: "改善度", score: evaluation.improvementScore)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                } else if let evaluationError {
                    Text(evaluationError)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 160, alignment: .topLeading)
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(resultCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    
    @ViewBuilder
    func resultImageView(image: UIImage?, title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 26, weight: .bold))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 168)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(resultCardBackground)
                    .frame(height: 168)
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
    
    func fetchTimer() {
            resultTimer = UserDefaults.standard.double(forKey: "saki-chan")
        }

    private var resultBackground: Color {
        Color(red: 253 / 255, green: 253 / 255, blue: 250 / 255)
    }

    private var resultCardBackground: Color {
        Color(red: 214 / 255, green: 214 / 255, blue: 214 / 255)
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
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color(red: 239 / 255, green: 132 / 255, blue: 69 / 255))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
