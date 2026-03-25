import CoreGraphics
import Foundation

public struct WorkspaceLayoutMetrics: Hashable, Sendable {
    public var interColumnSpacing: CGFloat
    public var interRowSpacing: CGFloat
    public var defaultColumnWidth: CGFloat
    public var regularColumnWidthFraction: CGFloat
    public var zoomedColumnWidthFraction: CGFloat
    public var verticalRowPeek: CGFloat
    public var alwaysCenterFocusedPaneHorizontally: Bool

    public init(
        interColumnSpacing: CGFloat = 28,
        interRowSpacing: CGFloat = 0,
        defaultColumnWidth: CGFloat = 720,
        regularColumnWidthFraction: CGFloat = 2.0 / 3.0,
        zoomedColumnWidthFraction: CGFloat = 0.92,
        verticalRowPeek: CGFloat = 28,
        alwaysCenterFocusedPaneHorizontally: Bool = false
    ) {
        self.interColumnSpacing = interColumnSpacing
        self.interRowSpacing = interRowSpacing
        self.defaultColumnWidth = defaultColumnWidth
        self.regularColumnWidthFraction = regularColumnWidthFraction
        self.zoomedColumnWidthFraction = zoomedColumnWidthFraction
        self.verticalRowPeek = verticalRowPeek
        self.alwaysCenterFocusedPaneHorizontally = alwaysCenterFocusedPaneHorizontally
    }
}

public struct WorkspaceRowFrame: Identifiable, Hashable, Sendable {
    public let id: WorkspaceRow.ID
    public let rect: CGRect
    public let isFocused: Bool

    public init(id: WorkspaceRow.ID, rect: CGRect, isFocused: Bool) {
        self.id = id
        self.rect = rect
        self.isFocused = isFocused
    }
}

public struct ColumnPresentation: Identifiable, Hashable, Sendable {
    public let id: WorkspaceColumn.ID
    public let frame: CGRect
    public let rows: [WorkspaceRowFrame]
    public let isFocused: Bool
    public let isVisible: Bool

    public init(
        id: WorkspaceColumn.ID,
        frame: CGRect,
        rows: [WorkspaceRowFrame],
        isFocused: Bool,
        isVisible: Bool
    ) {
        self.id = id
        self.frame = frame
        self.rows = rows
        self.isFocused = isFocused
        self.isVisible = isVisible
    }
}

public struct WorkspaceSpacePresentation: Identifiable, Hashable, Sendable {
    public let id: WorkspaceRow.ID
    public let columnID: WorkspaceColumn.ID
    public let rect: CGRect
    public let isFocused: Bool

    public init(id: WorkspaceRow.ID, columnID: WorkspaceColumn.ID, rect: CGRect, isFocused: Bool) {
        self.id = id
        self.columnID = columnID
        self.rect = rect
        self.isFocused = isFocused
    }
}

public struct WorkspaceLanePresentation: Identifiable, Hashable, Sendable {
    public let id: Int
    public let frame: CGRect
    public let contentFrame: CGRect
    public let contentSize: CGSize
    public let contentOffsetX: CGFloat
    public let topInset: CGFloat
    public let bottomInset: CGFloat
    public let spaces: [WorkspaceSpacePresentation]
    public let focusedSpaceID: WorkspaceRow.ID?
    public let scrollTargetSpaceID: WorkspaceRow.ID?

    public init(
        id: Int,
        frame: CGRect,
        contentFrame: CGRect,
        contentSize: CGSize,
        contentOffsetX: CGFloat,
        topInset: CGFloat,
        bottomInset: CGFloat,
        spaces: [WorkspaceSpacePresentation],
        focusedSpaceID: WorkspaceRow.ID?,
        scrollTargetSpaceID: WorkspaceRow.ID?
    ) {
        self.id = id
        self.frame = frame
        self.contentFrame = contentFrame
        self.contentSize = contentSize
        self.contentOffsetX = contentOffsetX
        self.topInset = topInset
        self.bottomInset = bottomInset
        self.spaces = spaces
        self.focusedSpaceID = focusedSpaceID
        self.scrollTargetSpaceID = scrollTargetSpaceID
    }
}

public struct WorkspaceViewportSnapshot: Hashable, Sendable {
    public let viewportSize: CGSize
    public let viewportRect: CGRect
    public let contentRect: CGRect
    public let contentOffsetX: CGFloat
    public let contentOffsetY: CGFloat
    public let activeLaneID: Int
    public let activeColumnID: WorkspaceColumn.ID
    public let activeRowID: WorkspaceRow.ID
    public let mode: WorkspaceViewportMode
    public let lanes: [WorkspaceLanePresentation]
    public let columns: [ColumnPresentation]

    public init(
        viewportSize: CGSize,
        viewportRect: CGRect,
        contentRect: CGRect,
        contentOffsetX: CGFloat,
        contentOffsetY: CGFloat,
        activeLaneID: Int,
        activeColumnID: WorkspaceColumn.ID,
        activeRowID: WorkspaceRow.ID,
        mode: WorkspaceViewportMode,
        lanes: [WorkspaceLanePresentation],
        columns: [ColumnPresentation]
    ) {
        self.viewportSize = viewportSize
        self.viewportRect = viewportRect
        self.contentRect = contentRect
        self.contentOffsetX = contentOffsetX
        self.contentOffsetY = contentOffsetY
        self.activeLaneID = activeLaneID
        self.activeColumnID = activeColumnID
        self.activeRowID = activeRowID
        self.mode = mode
        self.lanes = lanes
        self.columns = columns
    }
}

public struct WorkspaceLayoutEngine: Sendable {
    public var metrics: WorkspaceLayoutMetrics

    public init(metrics: WorkspaceLayoutMetrics = WorkspaceLayoutMetrics()) {
        self.metrics = metrics
    }

    public func snapshot(
        for state: WorkspaceState,
        viewportSize: CGSize
    ) -> WorkspaceViewportSnapshot {
        precondition(!state.columns.isEmpty, "Workspace requires at least one column.")

        let viewportRect = CGRect(origin: .zero, size: viewportSize)
        let laneLayouts = laneLayouts(for: state, viewportSize: viewportSize)
        let activeLaneIndex = state.activeRowIndex
        let activeLane = laneLayouts[activeLaneIndex]
        let targetOffsetY = offsetToCenterVertically(
            frame: CGRect(x: 0, y: activeLane.originY, width: viewportSize.width, height: activeLane.frameHeight),
            viewportSize: viewportSize
        )
        let contentHeight = max(laneLayouts.last.map { $0.originY + $0.frameHeight } ?? viewportSize.height, viewportSize.height)
        let maxOffsetY = max(0, contentHeight - viewportSize.height)
        let clampedOffsetY = min(max(0, targetOffsetY), maxOffsetY)
        let contentWidth = max(laneLayouts.map(\.contentWidth).max() ?? viewportSize.width, viewportSize.width)

        let lanes = laneLayouts.map { lane in
            WorkspaceLanePresentation(
                id: lane.rowIndex,
                frame: CGRect(
                    x: 0,
                    y: lane.originY - clampedOffsetY,
                    width: viewportSize.width,
                    height: lane.frameHeight
                ),
                contentFrame: CGRect(
                    x: 0,
                    y: lane.originY,
                    width: viewportSize.width,
                    height: lane.frameHeight
                ),
                contentSize: CGSize(width: lane.contentWidth, height: lane.frameHeight),
                contentOffsetX: lane.contentOffsetX,
                topInset: lane.topInset,
                bottomInset: lane.bottomInset,
                spaces: lane.spaces.map {
                    WorkspaceSpacePresentation(
                        id: $0.rowID,
                        columnID: $0.columnID,
                        rect: $0.rect,
                        isFocused: $0.isFocused
                    )
                },
                focusedSpaceID: lane.spaces.first(where: { $0.isFocused })?.rowID,
                scrollTargetSpaceID: lane.scrollTargetSpaceID
            )
        }

        let presentations = laneLayouts.flatMap { lane in
            lane.spaces.map { space in
                ColumnPresentation(
                    id: space.columnID,
                    frame: CGRect(
                        x: space.rect.minX - lane.contentOffsetX,
                        y: lane.originY - clampedOffsetY,
                        width: max(space.rect.width, 0),
                        height: viewportSize.height
                    ),
                    rows: [
                        WorkspaceRowFrame(
                            id: space.rowID,
                            rect: CGRect(
                                x: space.rect.minX,
                                y: 0,
                                width: space.rect.width,
                                height: space.rect.height
                            ),
                            isFocused: space.isFocused
                        )
                    ],
                    isFocused: space.isFocused,
                    isVisible: true
                )
            }
        }

        return WorkspaceViewportSnapshot(
            viewportSize: viewportSize,
            viewportRect: viewportRect,
            contentRect: CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight),
            contentOffsetX: activeLane.contentOffsetX,
            contentOffsetY: clampedOffsetY,
            activeLaneID: state.activeRowIndex,
            activeColumnID: state.focus.columnID,
            activeRowID: state.focus.rowID,
            mode: state.viewportMode,
            lanes: lanes,
            columns: presentations
        )
    }

    private func offsetToCenter(frame: CGRect, viewportSize: CGSize) -> CGFloat {
        let viewportCenter = viewportSize.width / 2
        return frame.midX - viewportCenter
    }

    private func offsetToCenterVertically(frame: CGRect, viewportSize: CGSize) -> CGFloat {
        let viewportCenter = viewportSize.height / 2
        return frame.midY - viewportCenter
    }

    private func laneLayouts(for state: WorkspaceState, viewportSize: CGSize) -> [LaneLayout] {
        let laneCount = max(state.maxRowCount, 1)
        let zoomedWidth = max(
            min(viewportSize.width * metrics.zoomedColumnWidthFraction, viewportSize.width),
            metrics.defaultColumnWidth
        )
        let activeExpandedRowID: WorkspaceRow.ID? = {
            guard case .expandedSpaces(let expanded) = state.viewportMode,
                  expanded.contains(state.focus.rowID) else {
                return nil
            }
            return state.focus.rowID
        }()
        return (0..<laneCount).map { rowIndex in
            let laneColumns = state.columns(forRowIndex: rowIndex)
            let usesSinglePaneLane = laneColumns.count == 1
            var xCursor: CGFloat = 0
            var spaces: [LaneSpaceLayout] = []
            let isExpandedActiveLane = rowIndex == state.activeRowIndex && activeExpandedRowID == state.focus.rowID
            let rowScale = state.rowHeightScale(for: rowIndex)
            let tallestPreferredHeight = laneColumns.compactMap { $0.row(atLaneIndex: rowIndex)?.preferredHeight }.max() ?? 0
            let scaledLaneHeight = isExpandedActiveLane
                ? viewportSize.height
                : min(max(tallestPreferredHeight * rowScale, 0), viewportSize.height)
            let verticalInsets = laneInsets(
                rowIndex: rowIndex,
                laneCount: laneCount,
                viewportHeight: scaledLaneHeight,
                usesFullFrameLane: isExpandedActiveLane
            )
            let laneFrameHeight = scaledLaneHeight + verticalInsets.top + verticalInsets.bottom

            for column in laneColumns {
                guard let row = column.row(atLaneIndex: rowIndex) else { continue }
                let baseWidth = max(column.width, metrics.defaultColumnWidth)
                let isFocused = state.focus.columnID == column.id && state.focus.rowID == row.id
                let paneWidth = baseWidth * state.paneWidthScale(for: row.id)
                let rect: CGRect

                let desiredWidth: CGFloat
                if isExpandedActiveLane && isFocused {
                    desiredWidth = viewportSize.width
                } else {
                    switch state.viewportMode {
                    case .standard:
                        desiredWidth = paneWidth
                    case .expandedSpaces(let expanded):
                        if expanded.contains(row.id) {
                            desiredWidth = zoomedWidth
                        } else {
                            desiredWidth = paneWidth
                        }
                    }
                }
                let width = clampedPaneWidth(desiredWidth, viewportWidth: viewportSize.width)
                if usesSinglePaneLane && spaces.isEmpty && !isExpandedActiveLane && metrics.alwaysCenterFocusedPaneHorizontally {
                    xCursor = max((viewportSize.width - width) / 2, 0)
                }
                rect = CGRect(
                    x: xCursor,
                    y: isExpandedActiveLane && isFocused ? 0 : verticalInsets.top,
                    width: width,
                    height: isExpandedActiveLane && isFocused
                        ? viewportSize.height
                        : min(max(row.preferredHeight * rowScale, 0), viewportSize.height)
                )
                xCursor += width + metrics.interColumnSpacing
                spaces.append(
                    LaneSpaceLayout(
                        columnID: column.id,
                        rowID: row.id,
                        rect: rect,
                        isFocused: isFocused,
                        baseWidth: baseWidth
                    )
                )
            }

            let rememberedColumnID = state.rememberedColumnByRowIndex[rowIndex] ?? laneColumns.first?.id
            var adjustedSpaces = spaces
            var horizontalBleed: CGFloat = 0
            let centeringColumnID: WorkspaceColumn.ID? = {
                guard metrics.alwaysCenterFocusedPaneHorizontally,
                      !usesSinglePaneLane,
                      !isExpandedActiveLane else {
                    return nil
                }

                if rowIndex == state.activeRowIndex {
                    return state.focus.columnID
                }

                return rememberedColumnID
            }()

            if let centeringColumnID,
               let centeredSpace = adjustedSpaces.first(where: { $0.columnID == centeringColumnID }) {
                horizontalBleed = max((viewportSize.width - centeredSpace.rect.width) / 2, 0)
                adjustedSpaces = adjustedSpaces.map { space in
                    LaneSpaceLayout(
                        columnID: space.columnID,
                        rowID: space.rowID,
                        rect: space.rect.offsetBy(dx: horizontalBleed, dy: 0),
                        isFocused: space.isFocused,
                        baseWidth: space.baseWidth
                    )
                }
            }

            let targetSpace: LaneSpaceLayout?
            if let centeringColumnID {
                targetSpace = adjustedSpaces.first(where: { $0.columnID == centeringColumnID })
            } else {
                targetSpace = adjustedSpaces.first(where: { $0.columnID == rememberedColumnID }) ?? adjustedSpaces.first
            }

            let contentWidth = max(
                (adjustedSpaces.map { $0.rect.maxX }.max() ?? viewportSize.width) + horizontalBleed,
                viewportSize.width
            )
            let targetOffsetX = targetSpace.map { offsetToCenter(frame: $0.rect, viewportSize: viewportSize) } ?? 0
            let maxOffsetX = max(0, contentWidth - viewportSize.width)
            let clampedOffsetX = min(max(0, targetOffsetX), maxOffsetX)

            return LaneLayout(
                rowIndex: rowIndex,
                originY: originY(for: rowIndex, state: state, viewportHeight: viewportSize.height),
                frameHeight: laneFrameHeight,
                contentWidth: contentWidth,
                contentOffsetX: clampedOffsetX,
                topInset: verticalInsets.top,
                bottomInset: verticalInsets.bottom,
                scrollTargetSpaceID: targetSpace?.rowID,
                spaces: adjustedSpaces
            )
        }
    }

    private func originY(
        for rowIndex: Int,
        state: WorkspaceState,
        viewportHeight: CGFloat
    ) -> CGFloat {
        var cursor: CGFloat = 0
        for priorRowIndex in 0..<rowIndex {
            let laneColumns = state.columns(forRowIndex: priorRowIndex)
            let rowScale = state.rowHeightScale(for: priorRowIndex)
            let tallestPreferredHeight = laneColumns.compactMap { $0.row(atLaneIndex: priorRowIndex)?.preferredHeight }.max() ?? 0
            let scaledLaneHeight = min(max(tallestPreferredHeight * rowScale, 0),  viewportHeight)
            let verticalInsets = laneInsets(
                rowIndex: priorRowIndex,
                laneCount: max(state.maxRowCount, 1),
                viewportHeight: scaledLaneHeight,
                usesFullFrameLane: false
            )
            let laneFrameHeight = scaledLaneHeight + verticalInsets.top + verticalInsets.bottom
            cursor += laneFrameHeight
            if priorRowIndex < rowIndex {
                cursor += metrics.interRowSpacing
            }
        }
        return cursor
    }

    private struct LaneSpaceLayout {
        let columnID: WorkspaceColumn.ID
        let rowID: WorkspaceRow.ID
        let rect: CGRect
        let isFocused: Bool
        let baseWidth: CGFloat
    }

    private struct LaneLayout {
        let rowIndex: Int
        let originY: CGFloat
        let frameHeight: CGFloat
        let contentWidth: CGFloat
        let contentOffsetX: CGFloat
        let topInset: CGFloat
        let bottomInset: CGFloat
        let scrollTargetSpaceID: WorkspaceRow.ID?
        let spaces: [LaneSpaceLayout]
    }

    private func laneInsets(
        rowIndex: Int,
        laneCount: Int,
        viewportHeight: CGFloat,
        usesFullFrameLane: Bool
    ) -> (top: CGFloat, bottom: CGFloat) {
        if usesFullFrameLane {
            return (0, 0)
        }
        let peek = min(metrics.verticalRowPeek, max(0, viewportHeight / 4))
        if laneCount <= 1 {
            return (0, 0)
        }
        if rowIndex == 0 {
            return (0, peek)
        }
        if rowIndex == laneCount - 1 {
            return (peek, 0)
        }
        return (peek, peek)
    }

    private func clampedPaneWidth(_ desiredWidth: CGFloat, viewportWidth: CGFloat) -> CGFloat {
        min(max(desiredWidth, 0), max(viewportWidth, 0))
    }
}
