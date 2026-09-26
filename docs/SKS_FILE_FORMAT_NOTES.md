# `.sks` File Format Notes (Reference Only)

These notes exist purely as reference material from inspecting real `.sks` files shipped with
Xcode 27's SpriteKit project templates. **No OSS `.sks` support is planned** — see
[`ARCHITECTURE.md`](ARCHITECTURE.md) and [`ROADMAP.md`](ROADMAP.md) for what `bitzgroup/SpriteKit`
actually targets (the public runtime API surface, not Xcode's authoring tools). This file is not
a design spec and does not gate any implementation work; it's kept in case the question of `.sks`
support ever comes up again.

## What a `.sks` file physically is

`file`/`plutil` confirm every `.sks` is an **Apple binary property list** containing an
`NSKeyedArchiver` keyed archive (the same serialization `NSCoding` uses elsewhere in Foundation),
not a bespoke SpriteKit format. Structure:

- `$archiver`: always `"NSKeyedArchiver"`.
- `$version`: archiver format version (`100000` observed).
- `$objects`: a flat array of every archived value/object. Nested references are
  `CFKeyedArchiverUID` indices into this array (this is what makes the format graph-shaped rather
  than tree-shaped — e.g. shared point/rect value objects are reused by index).
- `$top`: the archive's named entry points (e.g. `root`, `_gkScene`, `_info`,
  `document.type`).
- Every archived object carries a `$class` UID pointing to a `$classes` record (the class name
  plus its full superclass chain), which is how the decoder picks the right `NSCoding`
  initializer — this is the private, undocumented part: the exact key names below are an
  implementation detail of Apple's `SKScene`/`SKNode`/`SKAction` `NSCoding` conformances, not a
  published format.

## Example 1: a scene file (Game.xctemplate's `GameScene.sks`)

Top-level shape:

```
$top.root            → the SKScene itself
$top._gkScene         → a GKScene wrapper (_entities: [], _graphs: [:]) — present even when empty
$top._info            → {_spriteKitVersion, _sceneEditorVersion, _gameplayKitKitVersion}
$top.document.type     → "com.apple.spritekit.scene"
```

The `SKScene` object's archived ivars are basically every property you'd set in code:
`_position`, `_anchorPoint`, `_zPosition`/`_zRotation`/`_xScale`/`_yScale`, `_children` (an
`NSArray` of child node UIDs), `_physicsWorld` (nested `PKPhysicsWorld` → `_bodies`/`_joints`),
`_backgroundColorR/G/B`, `_scaleMode`, `_camera`, `Scene_bounds`, `_visibleRect`, and a
`_PKPhysicsBody` for the scene-pin body. Child nodes (e.g. an `SKCameraNode` named `"camera"`, an
`SKLabelNode` named `"helloLabel"`) are archived the same way, recursively, each with its own
`_children`, `_position`, physics body, etc. An `SKLabelNode` additionally archives
`_text`/`_fontName`/`_fontSize`/`_horizontalAlignmentMode`/font color components.

Physics bodies (`PKPhysicsBody`, the private class backing `SKPhysicsBody`) archive shape data
(`_shapeType`, `_radius`/`_size`, `_edgeRadius`, `_p0`) plus every physics property
(`friction`, `restitution`, `density`, `dynamic`, bitmasks, damping, etc.) — a full snapshot of
whatever was set in the Scene Editor's inspector.

Every node also carries editor-only metadata that has nothing to do with runtime behavior:
`_PB_previewSKNodeCustomClassName`, `_PB_previewSpriteShaderUniforms`,
`_PB_previewSKEditorSceneCameraNode`, `_PB_previewSKNodeUniqueID`, etc. — these are how the Scene
Editor round-trips its own UI state (custom class names typed into the inspector, per-node stable
IDs for the editor's undo stack) and are simply ignored by `SKScene(fileNamed:)` at runtime.

## Example 2: an action library file (Game.xctemplate's `Actions.sks`)

Different top-level shape entirely — no scene, no `GKScene`, no `_info`:

```
$top.root → {"actions": {"Pulse": <SKAction>}}
```

i.e. an action-library `.sks` archives a plain dictionary keyed by the action's name (as typed in
the Scene Editor's action library panel), each value an `SKAction` object graph. The sample
`Pulse` action is an `SKAction` sequence/group (`_actions`: array of child action UIDs) of scale
actions, each archiving `_duration`, `_timingMode`, `_beginTime`, `_finished`/`_isRunning` — the
same private ivars `SKAction`'s own `NSCoding` implementation would archive if you called
`NSKeyedArchiver` on it yourself.

Other `.sks`-suffixed templates (`SpriteKit Particle File.xctemplate`,
`SpriteKit Tile Set.xctemplate`) follow the same pattern: same binary-plist/keyed-archiver
envelope, different root object type (`SKEmitterNode`, `SKTileSet`) under `$top.root`.

## Practical takeaways

- The format is **versioned by embedded version numbers**
  (`_spriteKitVersion`/`_sceneEditorVersion`/`_gameplayKitKitVersion` in `$top._info`), which
  cross-checks the earlier concern about it being an Apple-internal, undocumented schema that can
  shift between Xcode releases without notice.
- Reproducing it would mean reimplementing `NSKeyedArchiver`'s bplist encoding *and*
  reverse-engineering the private ivar-level `NSCoding` layout of `SKScene`/`SKNode`/`SKAction`/
  `PKPhysicsBody`/`SKCameraNode`/`SKLabelNode`/etc. — and redoing that exercise per node/action
  type as they're added. This matches the earlier assessment: technically inspectable (as above),
  but not something worth committing `bitzgroup/SpriteKit` to.

## How these were produced

```sh
xcodebuild -version   # confirms installed Xcode version
find /Applications/Xcode.app -iname "*.sks"   # locate template .sks files
file some.sks          # confirms "Apple binary property list"
plutil -p some.sks      # human-readable dump of the NSKeyedArchiver structure
```

Both files inspected here came from Xcode 27.0 (build 27A266a)'s
`Project Templates/iOS/Application/Game.xctemplate/SpriteKit/` directory.
