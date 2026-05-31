import SwiftUI
import MusicKit

struct HomeView: View {
    @StateObject private var viewModel = MusicViewModel(musicService: MusicServiceImpl())
    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    
                    Text("ライブラリの曲一覧を取得")
                        .font(.headline)
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top) {
                            if viewModel.songs.isEmpty {
                                Text("Empty Playlist")
                            } else {
                                ForEach(Array(viewModel.songs)) { song in
                                    NavigationLink {
                                        PhotobeforeView(beforeImage: $beforeImage, afterImage: $afterImage)
                                    } label: {
                                        VStack(alignment: .leading) {
                                            if let artwork = song.artwork {
                                                ArtworkImage(artwork, width: 100, height: 100)
                                            } else {
                                                Image(systemName: "music.note")
                                                    .frame(width: 100, height: 100, alignment: .leading)
                                            }
                                            VStack(alignment: .leading) {
                                                Text(song.title)
                                                    .font(.headline)
                                                    .frame(width: 100)
                                                    .lineLimit(1)
                                                Text(song.artistName)
                                                    .font(.caption)
                                            }
                                        }
                                        .padding(.horizontal, 5)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding()
                    }
    //                Text(viewModel.recommendedPlayLisits.first?.name ?? "ありません")
                }
                .onAppear() {
                    Task {
                        await viewModel.authorize()
                        try await viewModel.fetchSongs()
                    }
                }
                Button{
                    
                } label: {
                    Text("ゆったり")
                        .font(.system(size: 38))
                        .foregroundStyle(.black)
                        .frame(width:300, height: 100)
                        .background(Color(red: 183 / 255, green: 169 / 255, blue: 154 / 255))
                        .cornerRadius(12)
                }
                Button{
                    
                } label: {
                    Text("がっつり")
                        .font(.system(size: 38))
                        .foregroundStyle(.black)
                        .frame(width:300, height: 100)
                        .background(Color(red: 215 / 255, green: 184 / 255, blue: 163 / 255))
                        .cornerRadius(12)
                }
            }
        }
    }
}
#Preview {
    HomeView()
}
