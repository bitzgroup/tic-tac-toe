import GameplayKit
import SpriteKit
import XCTest

/// A component a game defines, with state of its own.
final class GameDefinedComponent: GKComponent {
    var value = 1
}

/// An entity subclass a game defines, with no state of its own.
final class GameDefinedEntity: GKEntity {}

/// Records `GKEntity`'s and `GKComponent`'s `NSCopying`, for bitzgroup/GameplayKit, which has no
/// `copy()` on either.
///
/// Swift imports `copy()` as returning a non-optional `Any`, so a `nil` result crashes the caller;
/// these tests call `copy` through the Objective-C runtime to see `nil` safely.
final class GKEntityCopyParityTests: XCTestCase {
    private func copy(_ object: NSObject) -> AnyObject? {
        object.perform(NSSelectorFromString("copy"))?.takeRetainedValue()
    }

    /// An entity holding a component the game defines, or an entity subclass the game defines,
    /// copies to `nil`, even when the component overrides nothing and the subclass is empty.
    func testEntityWithGameDefinedClassesCopiesToNil() {
        let entity = GKEntity()
        entity.addComponent(GameDefinedComponent())

        XCTAssertNil(copy(entity))
        XCTAssertNil(copy(GameDefinedEntity()))
    }

    /// An entity of only GameplayKit and SpriteKit classes copies as if archived and unarchived:
    /// a new entity with new components attached to it, and a `GKSKNodeComponent`'s node a new,
    /// parentless node with the original's properties, its `entity` the copy.
    func testEntityOfFrameworkClassesCopiesItsComponents() throws {
        XCTAssertEqual((try XCTUnwrap(copy(GKEntity())) as? GKEntity)?.components.count, 0)

        let node = SKNode()
        node.name = "n"
        node.position = CGPoint(x: 5, y: 6)
        SKNode().addChild(node)
        let component = GKSKNodeComponent(node: node)
        let entity = GKEntity()
        entity.addComponent(component)

        let entityCopy = try XCTUnwrap(copy(entity) as? GKEntity)
        XCTAssertFalse(entityCopy === entity)
        let componentCopy = try XCTUnwrap(entityCopy.component(ofType: GKSKNodeComponent.self))
        XCTAssertFalse(componentCopy === component)
        XCTAssertTrue(componentCopy.entity === entityCopy)
        XCTAssertFalse(componentCopy.node === node)
        XCTAssertEqual(componentCopy.node.name, "n")
        XCTAssertEqual(componentCopy.node.position, CGPoint(x: 5, y: 6))
        XCTAssertNil(componentCopy.node.parent)
        XCTAssertTrue(componentCopy.node.entity === entityCopy)
        XCTAssertTrue(component.entity === entity)
        XCTAssertTrue(node.entity === entity)
    }

    /// A copied entity's agent keeps none of its state: position and maximum speed come back as 0.
    func testEntityCopyDropsAgentState() throws {
        let agent = GKAgent2D()
        agent.position = vector_float2(3, 4)
        agent.maxSpeed = 7
        let entity = GKEntity()
        entity.addComponent(agent)

        let entityCopy = try XCTUnwrap(copy(entity) as? GKEntity)
        let agentCopy = try XCTUnwrap(entityCopy.component(ofType: GKAgent2D.self))
        XCTAssertEqual(agentCopy.position, vector_float2(0, 0))
        XCTAssertEqual(agentCopy.maxSpeed, 0)
    }

    /// A component copied on its own is a new, unattached instance of its class with none of the
    /// original's state, a game-defined component included.
    func testComponentCopyIsAFreshInstance() throws {
        let component = GameDefinedComponent()
        component.value = 3
        GKEntity().addComponent(component)

        let componentCopy = try XCTUnwrap(copy(component) as? GameDefinedComponent)
        XCTAssertFalse(componentCopy === component)
        XCTAssertNil(componentCopy.entity)
        XCTAssertEqual(componentCopy.value, 1)

        let agent = GKAgent2D()
        agent.position = vector_float2(3, 4)
        agent.maxSpeed = 7
        agent.radius = 2
        agent.behavior = GKBehavior(goal: GKGoal(toWander: 1), weight: 1)
        let agentCopy = try XCTUnwrap(copy(agent) as? GKAgent2D)
        XCTAssertEqual(agentCopy.position, vector_float2(0, 0))
        XCTAssertEqual(agentCopy.maxSpeed, 1)
        XCTAssertEqual(agentCopy.radius, 0.5)
        XCTAssertNil(agentCopy.behavior)
    }
}
