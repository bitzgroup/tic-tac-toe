import SpriteKit
import SwiftUI

/// Hosts `MenuScene` via SwiftUI's native `SpriteView` — the recommended way to combine
/// SwiftUI and SpriteKit, matching `bitzgroup/SpriteKit`'s own `:spritekit-compose` on Android
/// (see `docs/ARCHITECTURE.md`). Scene-to-scene navigation (`MenuScene` → `GameScene` → New Game)
/// happens entirely inside the SpriteKit layer via `view?.presentScene(_:transition:)`; SwiftUI
/// only ever presents the first scene.
struct ContentView: View {
    private let scene: SKScene = MenuScene(size: CGSize(width: 1080, height: 1920))

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
