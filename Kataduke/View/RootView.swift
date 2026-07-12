import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if authViewModel.isSignedIn {
                ContentView()
            } else {
                LoginView()
            }
        }
    }
}
