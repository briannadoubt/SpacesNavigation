import Foundation

public enum WorkspaceDemoContent {
    public static let columns: [WorkspaceColumn] = [
        WorkspaceColumn(width: 700, rows: [
            WorkspaceRow(title: "shell"),
            WorkspaceRow(title: "logs"),
            WorkspaceRow(title: "build"),
            WorkspaceRow(title: "server")
        ]),
        WorkspaceColumn(width: 760, rows: [
            WorkspaceRow(title: "editor"),
            WorkspaceRow(title: "notes"),
            WorkspaceRow(title: "search")
        ]),
        WorkspaceColumn(width: 680, rows: [
            WorkspaceRow(title: "tests"),
            WorkspaceRow(title: "git"),
            WorkspaceRow(title: "monitor"),
            WorkspaceRow(title: "tail")
        ])
    ]

    public static func demoState() -> WorkspaceState {
        WorkspaceState(
            columns: columns,
            focus: .init(
                columnID: columns[1].id,
                rowID: columns[1].rows[0].id
            )
        )
    }

    public static let terminalLines: [String] = (1...60).map { index in
        "stream event \(index): terminal output continues to flow through the workspace surface."
    }
}
