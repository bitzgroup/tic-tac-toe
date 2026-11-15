import SwiftUI

/// SwiftUI app entry point. Hosts the game's SpriteKit scenes via `SpriteView` — see
/// `ContentView.swift`.
@main
struct TicTacToeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
