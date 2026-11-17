import SpriteKit
import UIKit

// Host app for the SpriteKit parity probes: it records what Apple's real SpriteKit does, so the
// behavior bitzgroup/SpriteKit mirrors on Android is checked against the framework itself rather
// than against documentation. Not part of the Tic-Tac-Toe game.
//
// A UI test picks a scenario with the `-scenario <name>` launch argument and reads the result from
// the `state` label, which is refreshed several times a second.

/// Counts frame-loop callbacks and records every press delivered to it.
final class ProbeScene: SKScene {
    var updates = 0
    var pressLog: [String] = []
    /// When `false`, the forwarding view controller passes presses on up the responder chain.
    var handlesPresses = true

    override func update(_ currentTime: TimeInterval) {
        updates += 1
    }

    private func log(_ phase: String, _ presses: Set<UIPress>) {
        for press in presses {
            pressLog.append("\(phase):\(press.type.probeName)")
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        log("began", presses)
    }

    /// Every touch delivered, as `<phase initial><tapCount>` (`b1`, `m1`, `e2`, ...).
    var touchLog: [String] = []
    /// For each touch delivered: how old its `timestamp` was on delivery, against `systemUptime`.
    var timestampLagsMs: [Int] = []
    var forces: Set<String> = []

    private func log(_ phase: String, _ touches: Set<UITouch>) {
        for touch in touches {
            touchLog.append("\(phase)\(touch.tapCount)")
            timestampLagsMs.append(Int((ProcessInfo.processInfo.systemUptime - touch.timestamp) * 1000))
            forces.insert("\(touch.force)/\(touch.maximumPossibleForce)")
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { log("b", touches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { log("m", touches) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { log("e", touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { log("c", touches) }

    override func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        log("changed", presses)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        log("ended", presses)
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        log("cancelled", presses)
    }
}

/// A child node that would take presses if SpriteKit delivered them to nodes below the scene.
final class ProbeChild: SKSpriteNode {
    var pressCount = 0

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        pressCount += presses.count
    }
}

extension UIPress.PressType {
    var probeName: String {
        switch self {
        case .upArrow: "up"
        case .downArrow: "down"
        case .leftArrow: "left"
        case .rightArrow: "right"
        case .select: "select"
        case .menu: "menu"
        case .playPause: "playPause"
        default: "other(\(rawValue))"
        }
    }
}

@main
final class ParityHostAppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = ParityHostSceneDelegate.self
        return configuration
    }
}

final class ParityHostSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = ProbeViewController()
        window?.makeKeyAndVisible()
    }
}

/// An `SKView` that can be made first responder, to see whether SpriteKit then hands presses on.
final class ProbeSKView: SKView {
    var acceptsFirstResponder = false
    override var canBecomeFirstResponder: Bool { acceptsFirstResponder }
}

final class ProbeViewController: UIViewController {
    let skView = ProbeSKView()
    var scene = ProbeScene(size: CGSize(width: 400, height: 400))
    let child = ProbeChild(color: .gray, size: CGSize(width: 400, height: 400))
    let label = UILabel()
    private var timer: Timer?

    private var scenario: String {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-scenario"), index + 1 < arguments.count else { return "" }
        return arguments[index + 1]
    }

    override func loadView() {
        view = skView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        child.position = CGPoint(x: 200, y: 200)
        child.isUserInteractionEnabled = true
        scene.addChild(child)
        label.numberOfLines = 0
        label.textColor = .white
        label.font = .systemFont(ofSize: 18)
        label.accessibilityIdentifier = "state"
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 80),
        ])

        switch scenario {
        case "presentPaused":
            scene.isPaused = true
            skView.presentScene(scene)
        case "touches":
            // Touches go to the scene itself, not the press-probe child covering it.
            child.isUserInteractionEnabled = false
            skView.presentScene(scene)
        case "forwardedPassedOn":
            scene.handlesPresses = false
            skView.presentScene(scene)
        default:
            skView.presentScene(scene)
        }
        if scenario == "pauseScene" { scene.isPaused = true }
        if scenario == "pauseView" { skView.isPaused = true }
        if scenario == "pressesWhilePaused" { scene.isPaused = true }

        if scenario == "viewFirstResponder" {
            skView.acceptsFirstResponder = true
            DispatchQueue.main.async { self.firstResponderResult = self.skView.becomeFirstResponder() }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.refresh() }
    }

    private var firstResponderResult: Bool?

    /// Forwarding scenarios hand every press to the scene, the way a tvOS game's view controller
    /// has to (SpriteKit itself never delivers presses to a scene). A press the scene doesn't
    /// handle (`handlesPresses == false`) continues up the responder chain via `super`.
    private var forwardsPresses: Bool { scenario.hasPrefix("forwarded") }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if forwardsPresses { scene.pressesBegan(presses, with: event) }
        if !forwardsPresses || !scene.handlesPresses { super.pressesBegan(presses, with: event) }
    }

    override func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if forwardsPresses { scene.pressesChanged(presses, with: event) }
        if !forwardsPresses || !scene.handlesPresses { super.pressesChanged(presses, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if forwardsPresses { scene.pressesEnded(presses, with: event) }
        if !forwardsPresses || !scene.handlesPresses { super.pressesEnded(presses, with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if forwardsPresses { scene.pressesCancelled(presses, with: event) }
        if !forwardsPresses || !scene.handlesPresses { super.pressesCancelled(presses, with: event) }
    }

    private func refresh() {
        label.text = [
            "scenePaused=\(scene.isPaused)",
            "viewPaused=\(skView.isPaused)",
            "updates=\(scene.updates)",
            "presses=\(scene.pressLog.joined(separator: ","))",
            "childPresses=\(child.pressCount)",
            "becameFirstResponder=\(firstResponderResult.map(String.init) ?? "n/a")",
            "touches=\(scene.touchLog.joined(separator: ","))",
            "maxTimestampLagMs=\(scene.timestampLagsMs.max() ?? -1)",
            "minTimestampLagMs=\(scene.timestampLagsMs.min() ?? -1)",
            "forces=\(scene.forces.sorted().joined(separator: ","))",
        ].joined(separator: " ")
    }
}
