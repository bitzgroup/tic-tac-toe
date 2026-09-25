pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    // Resolves/auto-provisions the JVM used to run the Gradle Daemon
    // (gradle/gradle-daemon-jvm.properties), so contributors don't need a matching JDK preinstalled.
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "TicTacToe"

include(":app")

// bitzgroup/SpriteKit, bitzgroup/GameplayKit, and bitzgroup/GKSKBridge, embedded as git
// submodules per each repo's own README "Usage as a git submodule" — not published/consumed as
// Maven artifacts. See docs/ARCHITECTURE.md.
include(":SpriteKit:spritekit", ":SpriteKit:spritekit-compose")
project(":SpriteKit:spritekit").projectDir = file("SpriteKit/spritekit")
project(":SpriteKit:spritekit-compose").projectDir = file("SpriteKit/spritekit-compose")

include(":GameplayKit:gameplaykit")
project(":GameplayKit:gameplaykit").projectDir = file("GameplayKit/gameplaykit")

// GKSKBridge carries no submodules of its own — its own gkskbridge/build.gradle.kts depends on
// :GameplayKit:gameplaykit and :SpriteKit:spritekit via plain Gradle project paths, which the two
// includes above already provide (see GKSKBridge's own docs/ARCHITECTURE.md).
include(":GKSKBridge:gkskbridge")
project(":GKSKBridge:gkskbridge").projectDir = file("GKSKBridge/gkskbridge")
