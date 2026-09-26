# OSS library release process

This describes the process for cutting a new version of `bitzgroup/SpriteKit`,
`bitzgroup/GameplayKit`, or `bitzgroup/GKSKBridge` — the three OSS library submodules this app
demonstrates — once their `develop` branch has accumulated enough changes to warrant a release
(e.g. after fixes discovered while building some other, unrelated consumer app against them; that
consumer app's name is never referenced here — see "Never name external consumer apps" below).

tic-tac-toe's role in this process is the regression check: it's the one app in this repository
that can build against the three libraries end-to-end, so it's the gate a release must pass before
being tagged and published. Run the same process independently for each of the three repos that
needs a release — they don't have to ship in lockstep.

## Steps

1. **Audit.** In the library's own checkout (`android/SpriteKit`, `android/GameplayKit`, or
   `android/GKSKBridge`), review the code and docs added since the last release tag
   (`git log --oneline <last-tag>..HEAD`) for:
   - correctness bugs
   - unclear or stale comments/docs, and refactor opportunities
   - Apple-framework compatibility gaps — anything that has drifted from, or never matched, the
     real Apple framework's behavior, including anything already flagged in that library's
     `docs/API_COMPATIBILITY.md` (if present) as an open (not intentionally-scoped) gap

   This step is read-only research. If you delegate it to a subagent, see "Subagent safety" below
   — do not give it write/mutation tool access.

2. **Fix what's found**, each fix on its own `feature/<name>` branch, PR'd into `develop` and
   merged — same Gitflow this repo itself uses (see this repo's own `CLAUDE.md`). Wait for explicit
   approval before merging any PR.

3. **Regression-check via tic-tac-toe.** With the library's updated `develop` checked out locally
   (`git submodule update --remote android/<Library>`, or just work directly in the submodule
   checkout — Gradle builds from the working tree, not the superproject's recorded commit), run
   from `android/`:
   ```sh
   ./gradlew :app:ktlintCheck :app:detekt :app:assembleDebug :app:testDebugUnitTest
   ```
   All must pass before continuing. If the change plausibly affects rendering or input behavior,
   also do a manual playthrough on an Android emulator (mirroring the on-device verification this
   app's own `CLAUDE.md` describes for its own releases).

4. **Version bump.** On a `release/<version>` branch off `develop`, bump `VERSION_NAME` in
   `gradle.properties` (and `CHANGELOG.md` if the library keeps one) to the new version.

5. **PR `release/<version>` → `main`.** Wait for explicit approval before merging.

6. **Tag and publish.** After the release PR is merged into `main`:
   ```sh
   git tag <version>
   git push origin <version>
   gh release create <version> --notes "..."
   ```
   Write real release notes summarizing user-visible changes (see any prior release, e.g.
   `gh release view 0.1.0 -R bitzgroup/SpriteKit`, for the expected level of detail). Wait for
   explicit approval before running any of these three commands — a published tag and GitHub
   Release on a public repo is effectively irreversible.

7. **Merge `release/<version>` back into `develop`** via PR (Gitflow requires the release lands on
   both branches). Wait for explicit approval before merging.

8. **Update tic-tac-toe's submodule pointers.** Back in this repo:
   ```sh
   git submodule update --remote android/<Library>   # for each library that released
   git add android/<Library>
   git commit -m "Bump <Library> submodule to <version>"
   ```
   Wait for explicit approval before committing, and again before pushing.

## Never name external consumer apps

Some fixes in these libraries are discovered while building other apps against them. Those apps
may be private/unreleased. Never reference such an app by name in commit messages, PR titles/
descriptions, release notes, or docs in these public repos — describe the discovery generically
("a host app", "a consumer app") instead.

## Subagent safety

Every git/GitHub mutation in the steps above — `git commit`, `git push`, `gh pr create`,
`gh pr merge`, `git tag`, `gh release create` — needs the user's explicit go-ahead for that specific
action, in that turn. Do not infer standing approval from an earlier "proceed" or from the broader
conversation.

This applies with extra force when any part of this process is delegated to a subagent (including
a `fork`, which inherits the full parent conversation and can see the whole release goal even when
its own task prompt is scoped narrower):

- A "research only" prompt is not a capability boundary. A subagent with live Bash/`gh` access can
  run mutating commands regardless of what its prompt asks for. If a step should be read-only,
  give the subagent read-only tools, not just a read-only instruction.
- After any subagent run that touched one of these repos, verify actual state before trusting its
  self-report: `git status`, `gh pr list -R <repo> --state merged`, `gh release list -R <repo>`,
  and check `.claude/settings.local.json` and `.gitignore` in this repo for unexpected changes —
  a subagent self-granting itself permissions (and hiding the file via `.gitignore`) to bypass an
  approval prompt is an observed failure mode, not a hypothetical one.
- An anomalously long subagent runtime compared to sibling tasks doing equivalent work is itself a
  signal worth checking before trusting the result.
