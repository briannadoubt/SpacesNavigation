# SpacesNavigation

`SpacesNavigation` is a Swift package for building a keyboard-first macOS workspace that feels spatial instead of grid-like.

It renders a row-first tiling workspace where:

- panes live in horizontal strips
- each row keeps its own horizontal offset
- vertical navigation moves between independently offset rows
- each pane can keep its own width
- each row can keep its own height
- expanded panes persist independently

The package owns the workspace model, layout engine, viewport math, and keyboard command plumbing. Visual styling is left to the host app through a view builder.

## What It Feels Like

This package is designed for terminal-style workspaces where keyboard navigation is the source of truth.

- `Cmd+Left` and `Cmd+Right` move across panes in the current row
- `Cmd+Up` and `Cmd+Down` move between rows while preserving each row's remembered horizontal position
- the focused pane stays spatially anchored by viewport movement
- distant panes overflow offscreen instead of shrinking into a dashboard or grid

The result is closer to a moving strip of tiled workspaces than a general-purpose pane grid.

## Package Layout

- [/Users/bri/dev/SpacesNavigation/Sources/SpacesNavigation/WorkspaceModels.swift](/Users/bri/dev/SpacesNavigation/Sources/SpacesNavigation/WorkspaceModels.swift)
  Core model types and commands such as `WorkspaceColumn`, `WorkspaceRow`, `WorkspaceFocus`, and `WorkspaceState`.
- [/Users/bri/dev/SpacesNavigation/Sources/SpacesNavigation/WorkspaceLayoutEngine.swift](/Users/bri/dev/SpacesNavigation/Sources/SpacesNavigation/WorkspaceLayoutEngine.swift)
  Deterministic frame computation for rows, panes, offsets, and viewport snapshots.
- [/Users/bri/dev/SpacesNavigation/Sources/SpacesNavigation/WorkspaceView.swift](/Users/bri/dev/SpacesNavigation/Sources/SpacesNavigation/WorkspaceView.swift)
  SwiftUI renderer that places panes from computed frames and hooks up keyboard commands.
- [/Users/bri/dev/SpacesNavigation/Sources/SpacesNavigation/WorkspaceStore.swift](/Users/bri/dev/SpacesNavigation/Sources/SpacesNavigation/WorkspaceStore.swift)
  Observable store for integrating the workspace into an app.
- [/Users/bri/dev/SpacesNavigation/Tests/SpacesNavigationTests/WorkspaceLayoutTests.swift](/Users/bri/dev/SpacesNavigation/Tests/SpacesNavigationTests/WorkspaceLayoutTests.swift)
  Regression coverage for focus movement, insertion, closing, overflow, independent row memory, persistent pane width, and persistent row height.

## Installation

Add the package as a local or remote Swift Package dependency:

```swift
dependencies: [
    .package(path: "/Users/bri/dev/SpacesNavigation")
]
```

Then add the product to your target:

```swift
.product(name: "SpacesNavigation", package: "SpacesNavigation")
```

## Basic Usage

Create a workspace state, wrap it in a store, and provide a pane view builder:

```swift
import SwiftUI
import SpacesNavigation

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
        WorkspaceView(store: store) { column, row, isFocused in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isFocused ? Color.accentColor : Color.secondary.opacity(0.25),
                        lineWidth: isFocused ? 2 : 1
                    )

                VStack(alignment: .leading, spacing: 8) {
                    Text(row.title)
                        .font(.headline)
                    Text("Column: \(column.id.uuidString.prefix(8))")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }
        }
    }
}
```

## Core Concepts

### `WorkspaceColumn`

A horizontal collection of panes. Columns are ordered and stable, but rows do not have to exist in every column.

### `WorkspaceRow`

A pane entry inside a column. Rows carry stable identity and lane placement through `laneIndex`.

### Row-first navigation

Each row lane remembers its own active column. If row 1 is centered on pane `c` and row 2 is centered on pane `a`, moving up and down returns to those remembered positions instead of snapping all rows to one shared horizontal scroll.

### Persistent pane width

Each pane stores its own width scale. Widening one pane does not widen its neighbors.

### Persistent row height

Each row stores its own height scale. Resizing one row does not resize every row in the workspace.

### Expanded panes

Expanded panes persist independently. A pane can remain expanded even after focus moves elsewhere.

## Keyboard Commands

The package wires these commands in `WorkspaceView`:

- `Cmd+Left`: focus previous pane in the current row
- `Cmd+Right`: focus next pane in the current row
- `Cmd+Up`: focus row above
- `Cmd+Down`: focus row below
- `Cmd+[`: move current column left
- `Cmd+]`: move current column right
- `Cmd+T`: create a pane to the right of the active pane
- `Cmd+W`: close active pane
- `Cmd+Return`: toggle expansion for the focused pane
- `Cmd+Shift+Up`: shrink the focused row height by 10%
- `Cmd+Shift+Down`: grow the focused row height by 10%
- `Cmd+Shift+Option+Up`: alias for shrinking the focused row height
- `Cmd+Shift+Option+Down`: alias for growing the focused row height
- `Cmd+Shift+Left`: shrink the focused pane width by 10%
- `Cmd+Shift+Right`: widen the focused pane width by 10%

## Demo App

A standalone macOS demo app lives in [/Users/bri/dev/SpacesNavigation/DemoApp](/Users/bri/dev/SpacesNavigation/DemoApp).

It shows how to:

- host the package inside a `NavigationSplitView`
- provide custom pane chrome with a view builder
- keep app-specific row naming outside the package
- expose a Settings window with the command list

Key files:

- [/Users/bri/dev/SpacesNavigation/DemoApp/Sources/DemoRootView.swift](/Users/bri/dev/SpacesNavigation/DemoApp/Sources/DemoRootView.swift)
- [/Users/bri/dev/SpacesNavigation/DemoApp/Sources/DemoSettingsView.swift](/Users/bri/dev/SpacesNavigation/DemoApp/Sources/DemoSettingsView.swift)
- [/Users/bri/dev/SpacesNavigation/DemoApp/Sources/SpacesNavigationDemoApp.swift](/Users/bri/dev/SpacesNavigation/DemoApp/Sources/SpacesNavigationDemoApp.swift)

Build the package tests:

```bash
swift test
```

Build the demo app:

```bash
xcodebuild -project /Users/bri/dev/SpacesNavigation/DemoApp/SpacesNavigationDemoApp.xcodeproj -scheme SpacesNavigationDemoApp -configuration Debug build
```

## Current Scope

`SpacesNavigation` is focused on layout and interaction infrastructure, not terminal rendering.

The package does:

- model workspace state
- compute frames deterministically
- manage keyboard-first navigation
- expose a SwiftUI container for rendering panes

The package does not:

- render terminal content
- enforce a visual style
- own app-specific naming or sidebar behavior

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
