//
//  ContentView.swift
//  Kataduke
//
//  Created by Saki on 2025/12/21.
//
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView{
            Tab("HOME",systemImage: "house"){
                HomeView()
            }
            Tab("RECORD",systemImage: "square.and.pencil"){
                MemoriesView()
            }
            Tab("RANKING",systemImage: "crown"){
                RankingView()
            }
        }
        
    }
}

#Preview {
    ContentView()
}

