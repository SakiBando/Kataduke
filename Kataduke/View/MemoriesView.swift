//
//  MemoriesView.swift
//  Kataduke
//
//  Created by Saki on 2026/02/01.
//

import SwiftUI
import SwiftData

struct MemoriesView: View {
    private enum SortOption: String, CaseIterable {
        case newest = "新しい順"
        case oldest = "古い順"
        case longest = "総時間が長い順"
    }

    @Query(sort: \SelectedImage.createdAt, order: .reverse) var memories: [SelectedImage]
    @Environment(\.modelContext) private var context
    @State private var memoryToDelete: SelectedImage?
    @State private var showDeleteAlert = false
    @State private var deleteErrorMessage: String?
    @State private var sortOption: SortOption = .newest
    private let sharedRecordService = SharedCleaningRecordService()
    
    var body: some View {
        NavigationStack {
            Group {
                if memories.isEmpty {
                    ContentUnavailableView("まだ記録はありません", systemImage: "photo.on.rectangle")
                } else {
                    List {
                        ForEach(sortedMemories, id: \.persistentModelID) { memory in
                            NavigationLink {
                                MemoryDetailView(memory: memory)
                            } label: {
                                MemoryRowView(memory: memory)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    memoryToDelete = memory
                                    showDeleteAlert = true
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("これまでの記録")
            .background(recordBackground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button {
                                sortOption = option
                            } label: {
                                Label(
                                    option.rawValue,
                                    systemImage: sortOption == option ? "checkmark" : ""
                                )
                            }
                        }
                    } label: {
                        Text("選択")
                    }
                }
            }
            .alert("記録を削除しますか？", isPresented: $showDeleteAlert) {
                Button("キャンセル", role: .cancel) {
                    memoryToDelete = nil
                }
                Button("削除", role: .destructive) {
                    if let memoryToDelete {
                        Task { await delete(memoryToDelete) }
                    }
                    memoryToDelete = nil
                }
            } message: {
                Text("この操作は取り消せません。")
            }
            .alert("削除エラー", isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { if !$0 { deleteErrorMessage = nil } }
            )) {
                Button("OK") { deleteErrorMessage = nil }
            } message: {
                Text(deleteErrorMessage ?? "")
            }
        }
    }

    private var sortedMemories: [SelectedImage] {
        switch sortOption {
        case .newest:
            return memories.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            return memories.sorted { $0.createdAt < $1.createdAt }
        case .longest:
            return memories.sorted { $0.elapsedTime > $1.elapsedTime }
        }
    }
    
    @MainActor
    private func delete(_ memory: SelectedImage) async {
        if let sharedRecordID = memory.sharedRecordID {
            do {
                try await sharedRecordService.deleteSharedRecord(recordID: sharedRecordID)
            } catch {
                deleteErrorMessage = error.localizedDescription
                return
            }
        }
        context.delete(memory)
        print("[MemoriesView] deleted memory: \(memory.createdAt)")
    }
}

private struct MemoryRowView: View {
    let memory: SelectedImage
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(recordMint.opacity(0.12))
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(recordMint)
            }
            .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 6) {
                Text(memory.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(recordText)
                Text("総時間 \(formattedDuration(memory.elapsedTime))")
                    .font(.subheadline)
                    .foregroundStyle(recordMint)
                if let improvementScore = memory.improvementScore {
                    Text("Score \(improvementScore > 0 ? "+" : "")\(improvementScore)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(recordYellow)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(recordMint.opacity(0.18), lineWidth: 1))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
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
                        .foregroundStyle(recordText)
                    Text("総時間 \(formattedDuration(memory.elapsedTime))")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(recordMint)
                }
                
                HStack(alignment: .top, spacing: 14) {
                    playedTracksSection
                    scoreSummarySection
                }
                
                comparisonCard
                
                memoryImageSection(title: "片付け前", data: memory.beforeImageData)
                memoryImageSection(title: "片付け後", data: memory.afterImageData)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(recordBackground)
        .navigationTitle("記録の詳細")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
        private var scoreSummarySection: some View {
            if memory.beforeTidinessScore != nil || memory.afterTidinessScore != nil || memory.improvementScore != nil {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Score", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(recordMint)
                    if let beforeScore = memory.beforeTidinessScore {
                        scoreLine("Before", beforeScore, color: .secondary)
                    }
                    if let afterScore = memory.afterTidinessScore {
                        scoreLine("After", afterScore, color: recordMint)
                    }
                    if let improvementScore = memory.improvementScore {
                        Text("\(improvementScore > 0 ? "+" : "")\(improvementScore)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(recordYellow)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 190, alignment: .topLeading)
                .padding(14)
                .background(Color.white.opacity(0.82))
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(recordMint.opacity(0.22), lineWidth: 1))
            }
        }

    @ViewBuilder
    private var playedTracksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Played songs", systemImage: "music.note")
                .font(.headline)
                .foregroundStyle(recordMint)

            if memory.playedTracks.isEmpty {
                Text("曲がありません")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(memory.playedTracks) { track in
                    HStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .foregroundStyle(recordMint)
                            .frame(width: 30, height: 30)
                            .background(recordMint.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            if !track.artistName.isEmpty {
                                Text(track.artistName)
                                    .font(.caption2)
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
        .frame(height: 190, alignment: .topLeading)
        .padding(14)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(recordMint.opacity(0.22), lineWidth: 1))
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
        .background(Color.white.opacity(0.86))
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

private let recordMint = Color(red: 69 / 255, green: 166 / 255, blue: 145 / 255)
private let recordYellow = Color(red: 244 / 255, green: 185 / 255, blue: 70 / 255)
private let recordText = Color(red: 40 / 255, green: 68 / 255, blue: 66 / 255)
private let recordBackground = Color(red: 253 / 255, green: 251 / 255, blue: 245 / 255)

private func formattedDuration(_ seconds: Double) -> String {
    let totalSeconds = max(0, Int(seconds.rounded(.down)))
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

private func scoreLine(_ title: String, _ score: Int, color: Color) -> some View {
    HStack {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
        Spacer()
        Text("\(score)")
            .font(.title3.weight(.bold))
            .foregroundStyle(color)
    }
}
