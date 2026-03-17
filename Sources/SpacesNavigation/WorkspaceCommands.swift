import SwiftUI

public struct WorkspaceCommands: Commands {
    private let send: (WorkspaceCommand) -> Void
    private let isEnabled: () -> Bool

    public init(
        send: @escaping (WorkspaceCommand) -> Void,
        isEnabled: @escaping () -> Bool = { true }
    ) {
        self.send = send
        self.isEnabled = isEnabled
    }

    public var body: some Commands {
        CommandMenu("Workspace") {
            Button("Focus Previous Space") {
                send(.focusPreviousColumn)
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command])
            .disabled(!isEnabled())

            Button("Focus Next Space") {
                send(.focusNextColumn)
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command])
            .disabled(!isEnabled())

            Button("Focus Row Up") {
                send(.focusRowUp)
            }
            .keyboardShortcut(.upArrow, modifiers: [.command])
            .disabled(!isEnabled())

            Button("Focus Row Down") {
                send(.focusRowDown)
            }
            .keyboardShortcut(.downArrow, modifiers: [.command])
            .disabled(!isEnabled())

            Divider()

            Button("Shrink Row Height") {
                send(.zoomWorkspaceOut)
            }
            .keyboardShortcut(.upArrow, modifiers: [.command, .shift])
            .disabled(!isEnabled())

            Button("Grow Row Height") {
                send(.zoomWorkspaceIn)
            }
            .keyboardShortcut(.downArrow, modifiers: [.command, .shift])
            .disabled(!isEnabled())

            Button("Shrink Focused Pane") {
                send(.shrinkFocusedPane)
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])
            .disabled(!isEnabled())

            Button("Widen Focused Pane") {
                send(.widenFocusedPane)
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])
            .disabled(!isEnabled())

            Divider()

            Button("Move Space Left") {
                send(.moveColumnLeft)
            }
            .keyboardShortcut("[", modifiers: [.command])
            .disabled(!isEnabled())

            Button("Move Space Right") {
                send(.moveColumnRight)
            }
            .keyboardShortcut("]", modifiers: [.command])
            .disabled(!isEnabled())

            Divider()

            Button("Create Pane") {
                send(.createPane)
            }
            .keyboardShortcut("t", modifiers: [.command])
            .disabled(!isEnabled())

            Button("New Row") {
                send(.createRow)
            }
            .keyboardShortcut("n", modifiers: [.command])
            .disabled(!isEnabled())

            Button("Close Active Pane") {
                send(.closeActivePane)
            }
            .keyboardShortcut("w", modifiers: [.command])
            .disabled(!isEnabled())

            Button("Toggle Expansion") {
                send(.toggleZoom)
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!isEnabled())
        }
    }
}
