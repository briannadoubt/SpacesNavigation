# Contributing to SpacesNavigation

## Setup

- Use Xcode 16 or newer with Swift 6 support.
- Keep changes focused on workspace state, layout, or interaction infrastructure.
- Host-app-specific concerns should stay outside this package whenever possible.
- Install `xcodegen` if you need to regenerate the demo project from `DemoApp/project.yml`.

## Local Checks

- Run `swift build`
- Run `swift test`
- Run `cd DemoApp && xcodegen generate`
- Run `xcodebuild -project DemoApp/SpacesNavigationDemoApp.xcodeproj -scheme SpacesNavigationDemoApp -configuration Debug CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" build` when touching the demo app or public SwiftUI integration points

## Change Guidelines

- Add or update regression tests for layout math and state transitions.
- Preserve deterministic snapshots and avoid coupling tests to animation timing.
- Document new public commands or behaviors in `README.md`.

## Pull Requests

- Explain the user-visible behavior change.
- Call out any viewport, focus, or persistence edge cases.
- Include screenshots or recordings when a visual change is easier to review than a diff.
