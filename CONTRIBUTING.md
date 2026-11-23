# Contributing to Tic-Tac-Toe

Thanks for your interest in contributing! This repo is a sample app, not a library: the same game
implemented on Apple's SpriteKit/GameplayKit and on their Android ports, to show the two behave
the same. Changes to the Android libraries themselves belong in their own repositories
([SpriteKit](https://github.com/bitzgroup/SpriteKit),
[GameplayKit](https://github.com/bitzgroup/GameplayKit),
[GKSKBridge](https://github.com/bitzgroup/GKSKBridge)), not in the `android/` submodules here.

## Branches and pull requests

This repo uses a Gitflow-style model: branch `feature/<name>` off `develop` and open your pull
request against `develop`. `main` only receives `release/*` and `hotfix/*` merges. CI must pass
before a pull request can be merged.

## Keep the two apps in sync

The iOS and Android apps share no code. Anything that must match between them — rules, AI
behavior, layout, animation timing, localized strings — is specified in
[`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md). Change the spec there first, then implement it on
**both** platforms in the same pull request.

## Before opening a pull request

See the README's "Building and running" section for setup. Run:

```sh
# from android/
./gradlew :app:ktlintCheck :app:detekt :app:assembleDebug :app:testDebugUnitTest

# from apple-platforms/ — CI only builds the iOS app, it doesn't run these tests
xcodebuild test -project TicTacToe.xcodeproj -scheme TicTacToe \
  -destination 'platform=iOS Simulator,name=<simulator>'
```

If you add a SpriteKit/GameplayKit parity probe, run it on both an iOS and a tvOS simulator (the
`SpriteKitParity`/`GameplayKitParity` schemes).

## Writing for readers outside the project

This is public OSS: comments, KDoc/doc comments, docs, commit messages, and PR descriptions are
read by people who have none of the maintainers' context. Write for them.

- **Describe the code as it is now, not how it got here.** Explain what something does and why.
  Don't use roadmap phase numbers ("added in Phase 2"), PR/issue numbers, or "previously"/"used
  to"/"now" as explanations in code comments. That history belongs in commit messages, PRs, and
  `docs/ROADMAP.md`.
- **Don't leave forward-looking notes that will go stale.** Avoid "until X is wired up" or "will
  be added later" in comments. If a limitation is real, state it plainly and record it in the
  docs (see below); when it's lifted, update or delete the comment in the same change.
- **Cross-references must resolve.** Pointing at a doc section by its heading (for example
  "see `docs/ARCHITECTURE.md`'s "Touch event routing" section") is fine — but make sure the
  section exists, and update references when you rename one.
- **English only** for docs, comments, and commit messages. (Localized UI strings are the only
  exception.)
- **No personal or machine-specific details.** No absolute local paths, email addresses, host
  names, tokens, or credentials. Never commit local configuration such as `local.properties`,
  `.claude/settings.local.json`, or `xcuserdata/`.
- **Don't name private consumer apps.** If a fix was found while building some other app against
  these libraries, describe it generically ("a host app").
