import SwiftUI

/// SwiftUI app entry point. Hosts the game's SpriteKit scenes via `SpriteView` — see
/// `ContentView.swift`.
///
/// Phase 0 scaffolding only: presents a blank `SKScene`, no `Game`/`Scenes` logic wired up yet —
/// see `docs/ROADMAP.md`.
@main
struct TicTacToeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
