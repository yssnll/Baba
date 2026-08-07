---
name: SwiftUI scroll-to-top controls
description: Reliable pattern for floating return-to-top controls in SwiftUI lists.
---

Use an always-present button over the `ScrollView` and scroll to a stable top anchor through `ScrollViewReader`. Avoid making the button's existence depend on a `GeometryReader` preference or a scroll-offset threshold when visibility is important.

**Why:** In this app, geometry-based offset detection repeatedly failed to make the control visible reliably in the delivered IPA, while the unconditional overlay removed that failure mode.

**How to apply:** Keep the anchor as the first item in the scroll content, place the control in the overlay `ZStack` with enough bottom padding to clear the tab bar, and animate only the scroll action rather than the control's presence.