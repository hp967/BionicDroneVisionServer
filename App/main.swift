import SwiftUI

@main
struct App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "drone")
                .font(.system(size: 60))
            Text("Bionic Drone Vision")
                .font(.title)
        }
        .padding()
    }
}
