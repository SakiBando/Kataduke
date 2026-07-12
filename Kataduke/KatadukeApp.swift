//
//  KatadukeApp.swift
//  Kataduke
//
//  Created by Saki on 2025/12/21.
//

import SwiftUI
import FirebaseCore

//@main
//struct KatadukeApp: App {
  //  var body: some Scene {
    //    WindowGroup {
      //      CleaningView()
       // }
    //}
//}

@main
struct KatadukeApp: App {
    @State private var image: UIImage? = nil
    @StateObject private var authViewModel: AuthViewModel

    init() {
        FirebaseApp.configure()
        _authViewModel = StateObject(wrappedValue: AuthViewModel())
    }

    var body: some Scene {
        WindowGroup {
//            CleaningView(image: $image)
            RootView()
                .environmentObject(authViewModel)
                .modelContainer(for: [ResultItem.self, SelectedImage.self, DraftCleaningSession.self])
        }
    }
}
