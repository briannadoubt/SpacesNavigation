[![CI](https://github.com/briannadoubt/SpacesNavigation/actions/workflows/ci.yml/badge.svg)](https://github.com/briannadoubt/SpacesNavigation/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-black.svg)](LICENSE)

# SpacesNavigation

`SpacesNavigation` is a Swift package for building keyboard-first macOS workspaces that feel spatial instead of grid-like.

It models a row-first tiling workspace where:

- panes live in horizontal strips
- each row keeps its own horizontal position memory
- vertical movement returns to that row’s remembered pane instead of snapping globally
- pane widths and row heights persist independently
- expanded panes remain expanded until explicitly toggled off

The package owns workspace state, layout math, viewport behavior, and command handling. The host app owns rendering and product-specific chrome.

## Requirements

- macOS 14+
- Xcode 16+ / Swift 6+

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/briannadoubt/SpacesNavigation.git", branch: "main")
]
```

```swift
.product(name: "SpacesNavigation", package: "SpacesNavigation")
```

## Basic Usage

```swift
import SpacesNavigation
import SwiftUI

struct ExampleWorkspace: View {
    @State private var store = WorkspaceStore(
        state: WorkspaceState(columns: [
            WorkspaceColumn(rows: [
                WorkspaceRow(title: "shell"),
                WorkspaceRow(title: "logs")
            ]),
            WorkspaceColumn(rows: [
                WorkspaceRow(title: "editor"),
                WorkspaceRow(title: "notes")
            ]),
            WorkspaceColumn(rows: [
                WorkspaceRow(title: "search")
            ])
        ])
    )

    var body: some View {
        WorkspaceView(store: store) { _, row, isFocused in
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(alignment: .topLeading) {
                    Text(row.title)
                        .padding(16)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isFocused ? Color.accentColor : Color.secondary.opacity(0.25),
                            lineWidth: isFocused ? 2 : 1
                        )
                }
        }
    }
}
```

## What It Covers

- `WorkspaceState` and its commands for navigation, insertion, closure, resizing, and zooming
- `WorkspaceLayoutEngine` for deterministic lane, pane, and viewport snapshots
- `WorkspaceView` for SwiftUI rendering with keyboard command plumbing
- `WorkspaceStore` for app integration

## Keyboard Commands

- `Cmd+Left`: focus previous pane in the current row
- `Cmd+Right`: focus next pane in the current row
- `Cmd+Up`: focus row above
- `Cmd+Down`: focus row below
- `Cmd+[`: move the current pane left
- `Cmd+]`: move the current pane right
- `Cmd+T`: create a pane to the right of the active pane
- `Cmd+W`: close the active pane
- `Cmd+Return`: toggle expansion for the focused pane
- `Cmd+Shift+Up`: shrink the focused row height by 10%
- `Cmd+Shift+Down`: grow the focused row height by 10%
- `Cmd+Shift+Left`: shrink the focused pane width by 10%
- `Cmd+Shift+Right`: widen the focused pane width by 10%

## Demo App

The repo includes a standalone macOS demo app in [DemoApp](DemoApp).

Build the package tests:

```bash
swift test
```

Build the demo app:

```bash
cd DemoApp
xcodegen generate
cd ..
xcodebuild -project DemoApp/SpacesNavigationDemoApp.xcodeproj -scheme SpacesNavigationDemoApp -configuration Debug CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" build
```

## Scope

`SpacesNavigation` is intentionally focused on layout and interaction infrastructure. It does not render terminal content, dictate a design system, or own app-specific naming and sidebar logic.

## License

MIT. See [LICENSE](LICENSE).

## Testing

The test suite covers:

- previous and next pane focus
- row up and down focus
- insertion to the right
- column movement
- viewport centering
- horizontal overflow without global shrinkage
- independent row offsets
- persistent per-pane width
- persistent per-row height
- safe close behavior when rows or panes disappear

## Requirements

- macOS 14+
- Swift 6
- Xcode 15+ recommended
