//
//  ShareView.swift
//  Kataduke
//
//  Created by Saki on 2026/07/25.
//

import SwiftUI

struct ShareView: View {
    @State private var records: [SharedCleaningRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    private let service = SharedCleaningRecordService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if records.isEmpty {
                    ContentUnavailableView("共有された記録はありません", systemImage: "person.2")
                } else {
                    List(records) { record in
                        NavigationLink {
                            SharedRecordDetailView(record: record)
                        } label: {
                            SharedRecordRowView(record: record)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Share")
            .refreshable {
                await loadRecords()
            }
            .task {
                await loadRecords()
            }
            .alert("読み込みエラー", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @MainActor
    private func loadRecords() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            records = try await service.fetchSharedRecords()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SharedRecordRowView: View {
    let record: SharedCleaningRecord

    var body: some View {
        HStack(spacing: 12) {
            profileIcon

            VStack(alignment: .leading, spacing: 4) {
                Text(record.ownerName)
                    .font(.headline)
                Text("掃除時間 \(String(format: "%.2f", record.elapsedTime)) 秒")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var profileIcon: some View {
        if let url = record.ownerIconURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .frame(width: 48, height: 48)
        }
    }
}

private struct SharedRecordDetailView: View {
    let record: SharedCleaningRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    profileIcon
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.ownerName)
                            .font(.title3.weight(.bold))
                        Text(record.createdAt.formatted(date: .complete, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(String(format: "%.2f 秒", record.elapsedTime))
                    .font(.system(size: 46, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(alignment: .top, spacing: 14) {
                    sharedImageView(title: "Before", url: record.beforeImageURL)
                    sharedImageView(title: "After", url: record.afterImageURL)
                }

                scoreSection
                playedTracksSection
            }
            .padding()
        }
        .navigationTitle("共有記録")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var profileIcon: some View {
        if let url = record.ownerIconURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 54, height: 54)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .frame(width: 54, height: 54)
        }
    }

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Gemini評価")
                .font(.headline)
            if let beforeScore = record.beforeTidinessScore {
                Text("片付け前: \(beforeScore) 点")
            }
            if let afterScore = record.afterTidinessScore {
                Text("片付け後: \(afterScore) 点")
            }
            if let improvementScore = record.improvementScore {
                Text("改善度: \(improvementScore > 0 ? "+" : "")\(improvementScore)点")
            }
            if record.beforeTidinessScore == nil,
               record.afterTidinessScore == nil,
               record.improvementScore == nil {
                Text("評価はありません")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var playedTracksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("再生した曲")
                .font(.headline)

            if record.playedTracks.isEmpty {
                Text("曲がありません")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(record.playedTracks) { track in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .fontWeight(.semibold)
                        if !track.artistName.isEmpty {
                            Text(track.artistName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func sharedImageView(title: String, url: URL?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            if let url {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 180)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ShareView()
}
