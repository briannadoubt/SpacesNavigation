import SwiftUI

struct DemoSettingsView: View {
    var body: some View {
        TabView {
            KeyboardCommandsPane()
                .tabItem {
                    Label("Keyboard", systemImage: "command")
                }
        }
        .tabViewStyle(.automatic)
        .frame(minWidth: 560, minHeight: 420)
    }
}

private struct KeyboardCommandsPane: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Keyboard")
                        .font(.title2.weight(.semibold))
                    Text("Workspace navigation is keyboard-first. These commands move focus, reorder spaces, and control expansion.")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    ForEach(Array(DemoKeyboardCommands.commands.enumerated()), id: \.offset) { index, command in
                        KeyboardCommandRow(command: command)

                        if index < DemoKeyboardCommands.commands.count - 1 {
                            Divider()
                                .padding(.leading, 108)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct KeyboardCommandRow: View {
    let command: DemoKeyboardCommand

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            KeyboardShortcutBadge(keys: command.keys)
                .frame(width: 92, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(command.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(command.description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct KeyboardShortcutBadge: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(nsColor: .tertiarySystemFill))
                    )
            }
        }
    }
}

private struct DemoKeyboardCommand: Identifiable {
    let id = UUID()
    let keys: [String]
    let title: String
    let description: String
}

private enum DemoKeyboardCommands {
    static let commands: [DemoKeyboardCommand] = [
        DemoKeyboardCommand(
            keys: ["⌘", "←"],
            title: "Focus Previous Space",
            description: "Move to the previous horizontal space in the current row."
        ),
        DemoKeyboardCommand(
            keys: ["⌘", "→"],
            title: "Focus Next Space",
            description: "Move to the next horizontal space in the current row."
        ),
        DemoKeyboardCommand(
            keys: ["⌘", "↑"],
            title: "Focus Row Up",
            description: "Move to the row above while preserving that row's remembered horizontal position."
        ),
        DemoKeyboardCommand(
            keys: ["⌘", "↓"],
            title: "Focus Row Down",
            description: "Move to the row below while preserving that row's remembered horizontal position."
        ),
        DemoKeyboardCommand(
            keys: ["⌘", "⇧", "↑"],
            title: "Shrink Row Height",
            description: "Decrease the focused row height by 10%, down to a minimum of 30%."
        ),
        DemoKeyboardCommand(
            keys: ["⌘", "⇧", "↓"],
            title: "Grow Row Height",
            description: "Increase the focused row height by 10%, up to the full 100% height."
        ),
        DemoKeyboardCommand(
            keys: ["⌘", "⇧", "⌥", "↑"],
            title: "Shrink Row Height",
            description: "Alias for decreasing the focused row height."
        ),
        DemoKeyboardCommand(
            keys: ["⌘", "⇧", "⌥", "↓"],
            title: "Grow Row Height",
            description: "Alias for increasing the focused row height."
        ),
        DemoKeyboardCommand(
            keys: ["⌘", "⇧", "←"],
            title: "Shrink Focused Pane",
            description: "Reduce the width of the focused pane by 10%."
        ),
        DemoKeyboardCommand(
            keys: ["⌘", "⇧", "→"],
            title: "Widen Focused Pane",
            description: "Increase the width of the focused pane by 10%."
        ),
        DemoKeyboardCommand(
            keys: ["⌘", "["],
            title: "Move Space Left",
            description: "Reorder the current column one position to the left."
        ),
        DemoKeyboardCommand(
            keys: ["⌘", "]"],
            title: "Move Space Right",
            description: "Reorder the current column one position to the right."
        ),
        DemoKeyboardCommand(
            keys: ["⌘", "T"],
            title: "Create Pane",
            description: "Open a new pane to the right of the active space."
        ),
        DemoKeyboardCommand(
            keys: ["⌘", "W"],
            title: "Close Active Pane",
            description: "Close the focused pane or remove its column when it is the last pane."
        ),
        DemoKeyboardCommand(
            keys: ["⌘", "↩"],
            title: "Toggle Expansion",
            description: "Expand or collapse the focused space while keeping that state persistent."
        )
    ]
}
