import OSLog

enum WorkspacePerformancePhase {
    static let command: StaticString = "Workspace.Command"
    static let snapshot: StaticString = "Workspace.Snapshot"
    static let verticalScrollTask: StaticString = "Workspace.VerticalScroll.Task"
    static let verticalScrollRequest: StaticString = "Workspace.VerticalScroll.Request"
    static let horizontalScrollTask: StaticString = "Workspace.HorizontalScroll.Task"
    static let horizontalScrollRequest: StaticString = "Workspace.HorizontalScroll.Request"
}

enum WorkspacePerformanceSignpost {
    struct Interval {
        fileprivate let name: StaticString
        fileprivate let state: OSSignpostIntervalState
    }

    private static let signposter = OSSignposter(
        subsystem: "dev.bri.SpacesNavigation",
        category: .pointsOfInterest
    )

    static func begin(
        _ name: StaticString,
        _ message: @autoclosure () -> String = ""
    ) -> Interval {
        let message = message()
        let state: OSSignpostIntervalState
        if message.isEmpty {
            state = signposter.beginInterval(name)
        } else {
            state = signposter.beginInterval(name, "\(message, privacy: .public)")
        }
        return Interval(name: name, state: state)
    }

    static func end(
        _ interval: Interval,
        _ message: @autoclosure () -> String = ""
    ) {
        let message = message()
        if message.isEmpty {
            signposter.endInterval(interval.name, interval.state)
        } else {
            signposter.endInterval(interval.name, interval.state, "\(message, privacy: .public)")
        }
    }

    static func emit(
        _ name: StaticString,
        _ message: @autoclosure () -> String = ""
    ) {
        let message = message()
        if message.isEmpty {
            signposter.emitEvent(name)
        } else {
            signposter.emitEvent(name, "\(message, privacy: .public)")
        }
    }
}
