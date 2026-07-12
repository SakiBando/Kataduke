//
//  MemoriesView.swift
//  Kataduke
//
//  Created by Saki on 2026/02/01.
//

import SwiftUI
import SwiftData

struct MemoriesView: View {
    @Query(sort: \SelectedImage.createdAt, order: .reverse) var memories: [SelectedImage]
    
    var body: some View {
        NavigationStack {
            Group {
                if memories.isEmpty {
                    ContentUnavailableView("まだ記録はありません", systemImage: "photo.on.rectangle")
                } else {
                    List(memories, id: \.persistentModelID) { memory in
                        NavigationLink {
                            MemoryDetailView(memory: memory)
                        } label: {
                            MemoryRowView(memory: memory)
                        }
                    }
                }
            }
            .navigationTitle("これまでの記録")
        }
    }
}

private struct MemoryRowView: View {
    let memory: SelectedImage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(memory.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.headline)
            Text("総時間 \(String(format: "%.2f", memory.elapsedTime)) 秒")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct MemoryDetailView: View {
    let memory: SelectedImage
    @State private var sliderProgress: CGFloat = 0.5
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(memory.createdAt.formatted(date: .complete, time: .shortened))
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("総時間 \(String(format: "%.2f", memory.elapsedTime)) 秒")
                        .font(.headline)
                }
                
                scoreSummarySection
                playedTracksSection
                
                comparisonCard
                
                memoryImageSection(title: "片付け前", data: memory.beforeImageData)
                memoryImageSection(title: "片付け後", data: memory.afterImageData)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("記録の詳細")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
        private var scoreSummarySection: some View {
            if memory.beforeTidinessScore != nil || memory.afterTidinessScore != nil || memory.improvementScore != nil {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Gemini評価")
                        .font(.headline)
                    if let beforeScore = memory.beforeTidinessScore {
                        Text("片付け前: \(beforeScore) 点")
                    }
                    if let afterScore = memory.afterTidinessScore {
                        Text("片付け後: \(afterScore) 点")
                    }
                    if let improvementScore = memory.improvementScore {
                        Text("改善度: \(improvementScore > 0 ? "+" : "")\(improvementScore)点")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.gray.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }

    @ViewBuilder
    private var playedTracksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("再生した曲")
                .font(.headline)

            if memory.playedTracks.isEmpty {
                Text("曲がありません")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(memory.playedTracks) { track in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .fontWeight(.semibold)
                        if !track.artistName.isEmpty {
                            Text(track.artistName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var comparisonCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("並べて比較")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("写真を見比べ")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.black)
            
            Text("スライダーを動かして片付け前と片付け後を切り替えられます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            sliderComparisonView
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)
    }
    
    @ViewBuilder
    private func memoryImageSection(title: String, data: Data?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.15))
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .overlay {
                        Text("写真がありません")
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }
    
    @ViewBuilder
    private var sliderComparisonView: some View {
        if memory.beforeImageData == nil && memory.afterImageData == nil {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.gray.opacity(0.12))
                .frame(height: 320)
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: "photo")
                            .font(.title2)
                        Text("写真がありません")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }
        } else {
            GeometryReader { geometry in
                let width = geometry.size.width
                let sliderX = min(max(width * sliderProgress, 0), width)
                
                ZStack {
                    comparisonBaseImage(data: memory.beforeImageData, title: "Before")
                    
                    comparisonBaseImage(data: memory.afterImageData, title: "After")
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: sliderX)
                        }
                    
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 3)
                        .position(x: sliderX, y: geometry.size.height / 2)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "arrow.left.and.right")
                                .foregroundStyle(.black)
                        }
                        .shadow(color: Color.black.opacity(0.18), radius: 8, y: 4)
                        .position(x: sliderX, y: geometry.size.height / 2)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            sliderProgress = min(max(value.location.x / max(width, 1), 0), 1)
                        }
                )
            }
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            }
        }
    }
    
    @ViewBuilder
    private func comparisonBaseImage(data: Data?, title: String) -> some View {
        ZStack(alignment: .topLeading) {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.12))
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "photo")
                                .font(.title2)
                            Text("写真がありません")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }
            }
            
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.92))
                .clipShape(Capsule())
                .padding(14)
        }
    }
}
