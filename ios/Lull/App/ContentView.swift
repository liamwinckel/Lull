import SwiftUI

struct ContentView: View {
    var body: some View {
        LampWebView()
            .ignoresSafeArea()
            .background(Color.black)
            .statusBarHidden(true)
            .persistentSystemOverlays(.hidden)
            .preferredColorScheme(.dark)
    }
}
