//
//  ContentView.swift
//  Kataduke
//
//  Created by Saki on 2025/12/21.
//
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        TabView {
            Tab("HOME",systemImage: "house"){
                NavigationStack {
                    HomeView()
                }
            }
            Tab("RECORD",systemImage: "square.and.pencil"){
                NavigationStack {
                    MemoriesView()
                }
            }
            Tab("SHARE",systemImage: "globe"){
                NavigationStack {
                    ShareView()
                }
            }
            Tab("ACCOUNT", systemImage: "person.circle") {
                NavigationStack {
                    AccountView()
                }
            }
        }
        
    }
}

#Preview {
    ContentView()
}
