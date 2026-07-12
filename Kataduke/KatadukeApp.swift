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

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
       let options = FirebaseOptions(contentsOfFile: path),
       !(options.apiKey?.isEmpty ?? true) {
        FirebaseApp.configure(options: options)
    } else {
        print("[Firebase] GoogleService-Info.plist is missing or invalid. Firebase will not be configured.")
    }

    return true
  }
}

@main
struct KatadukeApp: App {
    @State private var image: UIImage? = nil
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
//            CleaningView(image: $image)
            RootView()
                .environmentObject(authViewModel)
                .modelContainer(for: [ResultItem.self, SelectedImage.self, DraftCleaningSession.self])
        }
    }
}
