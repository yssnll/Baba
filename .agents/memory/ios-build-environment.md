---
name: iOS build environment
description: Native iOS targets and WidgetKit extensions must be compiled and signed on macOS with Xcode.
---

The project cannot produce or validate an iOS IPA in the Linux workspace because `xcodebuild`, the Apple SDKs, and SwiftUI/WidgetKit SDKs are unavailable there.

**Why:** WidgetKit, App Intents, AVFoundation, and signing depend on Apple SDKs; a Linux syntax check is useful but cannot replace an Xcode build.

**How to apply:** Run `xcodegen generate` and the provided build script on macOS or a macOS CI runner, then configure the `group.app.tilawa` App Group for signed widget builds. An unsigned IPA can verify packaging, but cannot make App Group-backed widget state work on a device.