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
    FirebaseApp.configure()

    return true
  }
}

@main
struct KatadukeApp: App {
    @State private var image: UIImage? = nil
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
//            CleaningView(image: $image)
            ContentView()
                .modelContainer(for: [ResultItem.self, SelectedImage.self])
        }
    }
}

