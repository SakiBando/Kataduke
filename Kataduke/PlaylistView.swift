//
//  PlaylistView.swift
//  Kataduke
//
//  Created by Saki on 2025/12/21.
//

import SwiftUI

struct PlaylistView: View {
    @State private var isShowCamera: Bool = false
    var body: some View {
        VStack{
            HStack{
                Button {
                    isShowCamera = true
                } label: {
                    Text("開始")
                }
                .sheet(isPresented: $isShowCamera) {
                    //ResultView(image: .constant(nil))
                }
                Button {
                    
                } label: {
                    Text("シャッフル")
                }
            }
        }
    }
}

#Preview {
    PlaylistView()
}
