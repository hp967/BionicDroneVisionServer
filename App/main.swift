import SwiftUI

@main
struct BionicDroneVisionServerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "drone")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Bionic Drone Vision")
                .font(.title)
            
            Text("iOS Vision Server")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
