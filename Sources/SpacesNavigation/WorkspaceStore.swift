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
        state.perform(command)
    }

    public func focusRowIndex(_ rowIndex: Int) {
        state.focusRowIndex(rowIndex)
    }
}
