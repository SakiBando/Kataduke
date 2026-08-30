import SwiftUI

struct PlayedSongsSheet: View {
    let tracks: [PlayedTrackInfo]
    let tintColor: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if tracks.isEmpty {
                        ContentUnavailableView("曲がありません", systemImage: "music.note")
                    } else {
                        ForEach(tracks) { track in
                            PlayedSongRow(track: track, tintColor: tintColor)
                                .padding(12)
                                .background(Color.white.opacity(0.84))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(tintColor.opacity(0.18), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding()
            }
            .background(Color(red: 253 / 255, green: 251 / 255, blue: 245 / 255))
            .navigationTitle("再生した曲")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PlayedSongRow: View {
    let track: PlayedTrackInfo
    let tintColor: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tintColor)
                .frame(width: 34, height: 34)
                .background(tintColor.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 40 / 255, green: 68 / 255, blue: 66 / 255))
                    .lineLimit(1)

                if !track.artistName.isEmpty {
                    Text(track.artistName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
    }
}
