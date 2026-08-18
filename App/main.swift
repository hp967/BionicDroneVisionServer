import SwiftUI

@main
struct BionicDroneVisionServerApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 20) {
                Image(systemName: "drone.front.closed")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Bionic Drone Vision")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Server Ready")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
        }
    }
}
