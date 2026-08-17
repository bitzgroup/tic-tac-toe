import SpriteKit
import SwiftUI

/// Hosts a blank `SKScene` via SwiftUI's native `SpriteView` — the recommended way to combine
/// SwiftUI and SpriteKit, matching `bitzgroup/SpriteKit`'s own `:spritekit-compose` on Android
/// (see `docs/ARCHITECTURE.md`).
///
/// A placeholder for Phase 0 — replaced by presenting `MenuScene` once Phase 2/3 land.
struct ContentView: View {
    private let scene: SKScene = {
        let scene = SKScene(size: CGSize(width: 1080, height: 1920))
        scene.scaleMode = .aspectFit
        scene.backgroundColor = .black
        return scene
    }()

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
