import CoreGraphics
import Foundation

public struct WorkspaceRow: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var preferredHeight: CGFloat
    public var laneIndex: Int

    public init(id: UUID = UUID(), title: String, preferredHeight: CGFloat = 320, laneIndex: Int = -1) {
        self.id = id
        self.title = title
        self.preferredHeight = preferredHeight
        self.laneIndex = laneIndex
    }
}

public struct WorkspaceColumn: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var width: CGFloat
    public var rows: [WorkspaceRow]

    public init(id: UUID = UUID(), width: CGFloat = 720, rows: [WorkspaceRow]) {
        self.id = id
        self.width = width
        self.rows = WorkspaceColumn.normalizedRows(rows)
    }

    public func row(atLaneIndex laneIndex: Int) -> WorkspaceRow? {
        rows.first(where: { $0.laneIndex == laneIndex })
    }

    private static func normalizedRows(_ rows: [WorkspaceRow]) -> [WorkspaceRow] {
        rows.enumerated()
            .map { index, row in
                var normalized = row
                if normalized.laneIndex < 0 {
                    normalized.laneIndex = index
                }
                return normalized
            }
            .sorted { lhs, rhs in
                if lhs.laneIndex == rhs.laneIndex {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.laneIndex < rhs.laneIndex
            }
    }
}

public struct WorkspaceFocus: Hashable, Sendable {
    public var columnID: WorkspaceColumn.ID
    public var rowID: WorkspaceRow.ID

    public init(columnID: WorkspaceColumn.ID, rowID: WorkspaceRow.ID) {
        self.columnID = columnID
        self.rowID = rowID
    }
}

public enum WorkspaceViewportMode: Hashable, Sendable {
    case standard
    case expandedSpaces(Set<WorkspaceRow.ID>)
}

public struct WorkspaceState: Hashable, Sendable {
    public static let minimumWorkspaceScale: CGFloat = 0.3
    public static let maximumWorkspaceScale: CGFloat = 1.0
    public static let workspaceScaleStep: CGFloat = 0.1
    public static let minimumFocusedPaneWidthScale: CGFloat = 0.5
    public static let maximumFocusedPaneWidthScale: CGFloat = 1.5
    public static let focusedPaneWidthScaleStep: CGFloat = 0.1

    public var columns: [WorkspaceColumn]
    public var focus: WorkspaceFocus
    public var viewportMode: WorkspaceViewportMode
    public var rowHeightScaleByRowIndex: [Int: CGFloat]
    public var paneWidthScaleByRowID: [WorkspaceRow.ID: CGFloat]
    public var rememberedColumnByRowIndex: [Int: WorkspaceColumn.ID]

    public init(
        columns: [WorkspaceColumn],
        focus: WorkspaceFocus,
        viewportMode: WorkspaceViewportMode = .standard,
        rowHeightScaleByRowIndex: [Int: CGFloat] = [:],
        paneWidthScaleByRowID: [WorkspaceRow.ID: CGFloat] = [:],
        rememberedColumnByRowIndex: [Int: WorkspaceColumn.ID] = [:]
    ) {
        self.columns = columns
        self.focus = focus
        self.viewportMode = viewportMode
        self.rowHeightScaleByRowIndex = WorkspaceState.seedRowHeightScales(
            columns: columns,
            rowHeightScaleByRowIndex: rowHeightScaleByRowIndex
        )
        self.paneWidthScaleByRowID = WorkspaceState.seedPaneWidthScales(
            columns: columns,
            paneWidthScaleByRowID: paneWidthScaleByRowID
        )
        self.rememberedColumnByRowIndex = WorkspaceState.seedRememberedColumns(
            columns: columns,
            focus: focus,
            rememberedColumnByRowIndex: rememberedColumnByRowIndex
        )
    }

    public init(columns: [WorkspaceColumn], viewportMode: WorkspaceViewportMode = .standard) {
        precondition(!columns.isEmpty, "Workspace requires at least one column.")
        precondition(columns.allSatisfy { !$0.rows.isEmpty }, "Every column must have at least one row.")
        self.columns = columns
        self.focus = WorkspaceFocus(columnID: columns[0].id, rowID: columns[0].rows[0].id)
        self.viewportMode = viewportMode
        self.rowHeightScaleByRowIndex = WorkspaceState.seedRowHeightScales(columns: columns, rowHeightScaleByRowIndex: [:])
        self.paneWidthScaleByRowID = WorkspaceState.seedPaneWidthScales(columns: columns, paneWidthScaleByRowID: [:])
        self.rememberedColumnByRowIndex = WorkspaceState.seedRememberedColumns(
            columns: columns,
            focus: self.focus,
            rememberedColumnByRowIndex: [:]
        )
    }

    public var activeColumnIndex: Int {
        columns.firstIndex(where: { $0.id == focus.columnID }) ?? 0
    }

    public var activeRowIndex: Int {
        guard let column = activeColumn else { return 0 }
        return column.rows.first(where: { $0.id == focus.rowID })?.laneIndex ?? 0
    }

    public var activeColumn: WorkspaceColumn? {
        columns[safe: activeColumnIndex]
    }

    public var maxRowCount: Int {
        (columns.flatMap(\.rows).map(\.laneIndex).max() ?? -1) + 1
    }

    public func columns(forRowIndex rowIndex: Int) -> [WorkspaceColumn] {
        columns.filter { $0.row(atLaneIndex: rowIndex) != nil }
    }

    public mutating func focusPreviousColumn() {
        let rowIndex = activeRowIndex
        let lane = columns(forRowIndex: rowIndex)
        guard
            let currentPosition = lane.firstIndex(where: { $0.id == focus.columnID })
        else { return }

        let newPosition = max(0, currentPosition - 1)
        setFocus(rowIndex: rowIndex, columnID: lane[newPosition].id)
    }

    public mutating func focusNextColumn() {
        let rowIndex = activeRowIndex
        let lane = columns(forRowIndex: rowIndex)
        guard
            let currentPosition = lane.firstIndex(where: { $0.id == focus.columnID })
        else { return }

        let newPosition = min(lane.count - 1, currentPosition + 1)
        setFocus(rowIndex: rowIndex, columnID: lane[newPosition].id)
    }

    public mutating func focusRowUp() {
        let newIndex = max(0, activeRowIndex - 1)
        focusRow(at: newIndex)
    }

    public mutating func focusRowDown() {
        let newIndex = min(maxRowCount - 1, activeRowIndex + 1)
        focusRow(at: newIndex)
    }

    public mutating func moveActiveColumnLeft() {
        let currentIndex = activeColumnIndex
        guard currentIndex > 0 else { return }
        columns.swapAt(currentIndex, currentIndex - 1)
    }

    public mutating func moveActiveColumnRight() {
        let currentIndex = activeColumnIndex
        guard currentIndex < columns.count - 1 else { return }
        columns.swapAt(currentIndex, currentIndex + 1)
    }

    @discardableResult
    public mutating func insertPaneToRight(
        width: CGFloat? = nil,
        rowTitle: String = "Terminal"
    ) -> WorkspaceColumn.ID {
        let referenceIndex = activeColumnIndex
        let newColumn = WorkspaceColumn(
            width: width ?? activeColumn?.width ?? 720,
            rows: [WorkspaceRow(title: rowTitle, laneIndex: activeRowIndex)]
        )
        columns.insert(newColumn, at: referenceIndex + 1)
        normalizeRememberedColumns()
        setFocus(rowIndex: activeRowIndex, columnID: newColumn.id)
        return newColumn.id
    }

    @discardableResult
    public mutating func insertPaneInNewRow(
        width: CGFloat? = nil,
        rowTitle: String = "Terminal"
    ) -> WorkspaceColumn.ID {
        let newLaneIndex = maxRowCount
        let insertIndex = columns.isEmpty ? 0 : activeColumnIndex + 1
        let newColumn = WorkspaceColumn(
            width: width ?? activeColumn?.width ?? 720,
            rows: [WorkspaceRow(title: rowTitle, laneIndex: newLaneIndex)]
        )

        if columns.isEmpty {
            columns = [newColumn]
        } else {
            columns.insert(newColumn, at: insertIndex)
        }

        normalizeRememberedColumns()
        setFocus(rowIndex: newLaneIndex, columnID: newColumn.id)
        return newColumn.id
    }

    public mutating func closeActivePane() {
        guard let columnIndex = columns.firstIndex(where: { $0.id == focus.columnID }) else { return }
        guard let row = columns[columnIndex].rows.first(where: { $0.id == focus.rowID }) else { return }
        let rowIndex = row.laneIndex

        if columns[columnIndex].rows.count > 1 {
            columns[columnIndex].rows.removeAll(where: { $0.id == focus.rowID })
            normalizeRememberedColumns()
            focusClosestAvailableRow(startingAt: rowIndex)
            return
        }

        guard columns.count > 1 else { return }
        columns.remove(at: columnIndex)
        normalizeRememberedColumns()
        focusClosestAvailableRow(startingAt: rowIndex)
    }

    public mutating func toggleZoom() {
        switch viewportMode {
        case .standard:
            viewportMode = .expandedSpaces([focus.rowID])
        case .expandedSpaces(var expanded):
            if expanded.contains(focus.rowID) {
                expanded.remove(focus.rowID)
            } else {
                expanded.insert(focus.rowID)
            }
            viewportMode = expanded.isEmpty ? .standard : .expandedSpaces(expanded)
        }
    }

    public mutating func exitZoom() {
        viewportMode = .standard
    }

    public mutating func centerActiveColumn() {
        viewportMode = .standard
    }

    public mutating func focusRowIndex(_ rowIndex: Int) {
        focusRow(at: rowIndex)
    }

    public mutating func zoomWorkspaceOut() {
        rowHeightScaleByRowIndex[activeRowIndex] = (rowHeightScale(for: activeRowIndex) - WorkspaceState.workspaceScaleStep).clamped(
            to: WorkspaceState.minimumWorkspaceScale...WorkspaceState.maximumWorkspaceScale
        )
    }

    public mutating func zoomWorkspaceIn() {
        rowHeightScaleByRowIndex[activeRowIndex] = (rowHeightScale(for: activeRowIndex) + WorkspaceState.workspaceScaleStep).clamped(
            to: WorkspaceState.minimumWorkspaceScale...WorkspaceState.maximumWorkspaceScale
        )
    }

    public mutating func shrinkFocusedPane() {
        paneWidthScaleByRowID[focus.rowID] = (paneWidthScale(for: focus.rowID) - WorkspaceState.focusedPaneWidthScaleStep).clamped(
            to: WorkspaceState.minimumFocusedPaneWidthScale...WorkspaceState.maximumFocusedPaneWidthScale
        )
    }

    public mutating func widenFocusedPane() {
        paneWidthScaleByRowID[focus.rowID] = (paneWidthScale(for: focus.rowID) + WorkspaceState.focusedPaneWidthScaleStep).clamped(
            to: WorkspaceState.minimumFocusedPaneWidthScale...WorkspaceState.maximumFocusedPaneWidthScale
        )
    }

    public func paneWidthScale(for rowID: WorkspaceRow.ID) -> CGFloat {
        paneWidthScaleByRowID[rowID] ?? 1.0
    }

    public func rowHeightScale(for rowIndex: Int) -> CGFloat {
        rowHeightScaleByRowIndex[rowIndex] ?? WorkspaceState.minimumWorkspaceScale
    }

    private mutating func focusRow(at rowIndex: Int) {
        let lane = columns(forRowIndex: rowIndex)
        guard !lane.isEmpty else { return }
        let targetColumnID = rememberedColumnByRowIndex[rowIndex]
            .flatMap { remembered in lane.first(where: { $0.id == remembered })?.id }
            ?? lane[0].id
        setFocus(rowIndex: rowIndex, columnID: targetColumnID)
    }

    private mutating func setFocus(rowIndex: Int, columnID: WorkspaceColumn.ID) {
        guard
            let columnIndex = columns.firstIndex(where: { $0.id == columnID }),
            let row = columns[columnIndex].row(atLaneIndex: rowIndex)
        else { return }

        focus = WorkspaceFocus(
            columnID: columnID,
            rowID: row.id
        )
        rememberedColumnByRowIndex[rowIndex] = columnID
    }

    private mutating func focusClosestAvailableRow(startingAt preferredRowIndex: Int) {
        guard maxRowCount > 0 else { return }

        let clampedPreferredRowIndex = preferredRowIndex.clamped(to: 0...(maxRowCount - 1))
        let higherRows: [Int]
        if clampedPreferredRowIndex + 1 < maxRowCount {
            higherRows = Array((clampedPreferredRowIndex + 1)..<maxRowCount)
        } else {
            higherRows = []
        }

        let candidateRows = [clampedPreferredRowIndex]
            + Array((0..<clampedPreferredRowIndex).reversed())
            + higherRows

        for rowIndex in candidateRows {
            let lane = columns(forRowIndex: rowIndex)
            guard !lane.isEmpty else { continue }
            focusRow(at: rowIndex)
            return
        }
    }

    private mutating func normalizeRememberedColumns() {
        normalizeExpandedSpaces()
        normalizeRowHeightScales()
        normalizePaneWidthScales()
        rememberedColumnByRowIndex = WorkspaceState.seedRememberedColumns(
            columns: columns,
            focus: focus,
            rememberedColumnByRowIndex: rememberedColumnByRowIndex
        )
    }

    private mutating func normalizeExpandedSpaces() {
        guard case .expandedSpaces(let expanded) = viewportMode else { return }
        let validRowIDs = Set(columns.flatMap(\.rows).map(\.id))
        let normalized = expanded.intersection(validRowIDs)
        viewportMode = normalized.isEmpty ? .standard : .expandedSpaces(normalized)
    }

    private mutating func normalizePaneWidthScales() {
        paneWidthScaleByRowID = WorkspaceState.seedPaneWidthScales(
            columns: columns,
            paneWidthScaleByRowID: paneWidthScaleByRowID
        )
    }

    private mutating func normalizeRowHeightScales() {
        rowHeightScaleByRowIndex = WorkspaceState.seedRowHeightScales(
            columns: columns,
            rowHeightScaleByRowIndex: rowHeightScaleByRowIndex
        )
    }

    private static func seedRememberedColumns(
        columns: [WorkspaceColumn],
        focus: WorkspaceFocus,
        rememberedColumnByRowIndex: [Int: WorkspaceColumn.ID]
    ) -> [Int: WorkspaceColumn.ID] {
        let maxRowCount = (columns.flatMap(\.rows).map(\.laneIndex).max() ?? -1) + 1
        var seeded: [Int: WorkspaceColumn.ID] = [:]

        for rowIndex in 0..<maxRowCount {
            let lane = columns.filter { $0.row(atLaneIndex: rowIndex) != nil }
            guard let firstColumn = lane.first else { continue }
            seeded[rowIndex] = rememberedColumnByRowIndex[rowIndex]
                .flatMap { remembered in lane.first(where: { $0.id == remembered })?.id }
                ?? firstColumn.id
        }

        if let focusColumn = columns.first(where: { $0.id == focus.columnID }),
           let rowIndex = focusColumn.rows.first(where: { $0.id == focus.rowID })?.laneIndex {
            seeded[rowIndex] = focus.columnID
        }

        return seeded
    }

    private static func seedPaneWidthScales(
        columns: [WorkspaceColumn],
        paneWidthScaleByRowID: [WorkspaceRow.ID: CGFloat]
    ) -> [WorkspaceRow.ID: CGFloat] {
        let validRowIDs = Set(columns.flatMap(\.rows).map(\.id))
        var seeded: [WorkspaceRow.ID: CGFloat] = [:]

        for rowID in validRowIDs {
            seeded[rowID] = paneWidthScaleByRowID[rowID, default: 1.0].clamped(
                to: WorkspaceState.minimumFocusedPaneWidthScale...WorkspaceState.maximumFocusedPaneWidthScale
            )
        }

        return seeded
    }

    private static func seedRowHeightScales(
        columns: [WorkspaceColumn],
        rowHeightScaleByRowIndex: [Int: CGFloat]
    ) -> [Int: CGFloat] {
        let validRowIndices = Set(columns.flatMap(\.rows).map(\.laneIndex))
        var seeded: [Int: CGFloat] = [:]

        for rowIndex in validRowIndices {
            seeded[rowIndex] = rowHeightScaleByRowIndex[rowIndex, default: WorkspaceState.minimumWorkspaceScale].clamped(
                to: WorkspaceState.minimumWorkspaceScale...WorkspaceState.maximumWorkspaceScale
            )
        }

        return seeded
    }
}

public enum WorkspaceCommand: Hashable, Sendable {
    case focusPreviousColumn
    case focusNextColumn
    case focusRowUp
    case focusRowDown
    case zoomWorkspaceOut
    case zoomWorkspaceIn
    case shrinkFocusedPane
    case widenFocusedPane
    case moveColumnLeft
    case moveColumnRight
    case centerActiveColumn
    case createPane
    case createRow
    case closeActivePane
    case toggleZoom
    case exitZoom
}

public extension WorkspaceState {
    mutating func perform(_ command: WorkspaceCommand) {
        switch command {
        case .focusPreviousColumn:
            focusPreviousColumn()
        case .focusNextColumn:
            focusNextColumn()
        case .focusRowUp:
            focusRowUp()
        case .focusRowDown:
            focusRowDown()
        case .zoomWorkspaceOut:
            zoomWorkspaceOut()
        case .zoomWorkspaceIn:
            zoomWorkspaceIn()
        case .shrinkFocusedPane:
            shrinkFocusedPane()
        case .widenFocusedPane:
            widenFocusedPane()
        case .moveColumnLeft:
            moveActiveColumnLeft()
        case .moveColumnRight:
            moveActiveColumnRight()
        case .centerActiveColumn:
            centerActiveColumn()
        case .createPane:
            _ = insertPaneToRight()
        case .createRow:
            _ = insertPaneInNewRow()
        case .closeActivePane:
            closeActivePane()
        case .toggleZoom:
            toggleZoom()
        case .exitZoom:
            exitZoom()
        }
    }
}

extension Array {
    fileprivate subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

extension Comparable {
    fileprivate func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
