import Foundation
import Observation

@MainActor
@Observable
public final class WorkspaceStore {
    public var state: WorkspaceState

    public init(state: WorkspaceState) {
        self.state = state
    }

    public func send(_ command: WorkspaceCommand) {
        let interval = WorkspacePerformanceSignpost.begin(
            WorkspacePerformancePhase.command,
            "command=\(String(describing: command)) fromRow=\(state.activeRowIndex) fromColumn=\(state.focus.columnID.uuidString)"
        )
        state.perform(command)
        WorkspacePerformanceSignpost.end(
            interval,
            "toRow=\(state.activeRowIndex) toColumn=\(state.focus.columnID.uuidString) toPane=\(state.focus.rowID.uuidString)"
        )
    }

    public func focusRowIndex(_ rowIndex: Int) {
        state.focusRowIndex(rowIndex)
    }
}
