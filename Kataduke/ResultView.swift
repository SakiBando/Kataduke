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
    var onFinishFlow: () -> Void
    @Environment(\.modelContext) var context
    @State private var evaluation: CleanupEvaluation?
        @State private var isEvaluating = false
        @State private var evaluationError: String?

    
    var body: some View {
        NavigationStack {
            VStack {
                Text(String(format: "%.2f",resultTimer)).font(.title)
                HStack(spacing: 16) {
                    resultImageView(image: beforeImage, title: "Before")
                    resultImageView(image: afterImage, title: "After")
                }
                .padding(.vertical, 12)
                
                evaluationSection
                
                Button{
                    saveImage()
                } label: {
                    Text("共有して保存")
                }
                
                Button{
                    saveImage()
                } label: {
                    Text("共有せずに保存")
                }
            }
            .onAppear() {
                fetchTimer()
            }
            .task {
                await evaluateCleanupIfNeeded()
            }
            
            NavigationLink(destination: MemoriesView()) {
                Text("To Memories View")
                
            }
        }
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
                    .font(.headline)
                
                if isEvaluating {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("片付け度を採点中...")
                            .foregroundStyle(.secondary)
                    }
                } else if let evaluation {
                    VStack(alignment: .leading, spacing: 10) {
                        scoreRow(title: "片付け前", score: evaluation.clampedBeforeScore)
                        scoreRow(title: "片付け後", score: evaluation.clampedAfterScore)
                        scoreRow(title: "改善度", score: evaluation.improvementScore)
                    }
                } else if let evaluationError {
                    Text(evaluationError)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    
    @ViewBuilder
    func resultImageView(image: UIImage?, title: String) -> some View {
        VStack {
            Text(title)
                .font(.headline)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 180)
                    .clipped()
                    .cornerRadius(12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 140, height: 180)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    }
            }
        }
    }
    
    
    func saveImage() {
        guard beforeImage != nil || afterImage != nil else {
            print("images not found")
            return
        }
        let beforeImageData = beforeImage?.jpegData(compressionQuality: 0.8)
                let afterImageData = afterImage?.jpegData(compressionQuality: 0.8)
                let record = SelectedImage(
                    elapsedTime: resultTimer,
                    beforeImageData: beforeImageData,
                    afterImageData: afterImageData,
                    beforeTidinessScore: evaluation?.clampedBeforeScore,
                    afterTidinessScore: evaluation?.clampedAfterScore,
                    improvementScore: evaluation?.improvementScore
                )
                context.insert(record)
                
                print("[ResultView] save complete. Returning HomeView")
                onFinishFlow()
    }
    
    func fetchTimer() {
            resultTimer = UserDefaults.standard.double(forKey: "saki-chan")
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
