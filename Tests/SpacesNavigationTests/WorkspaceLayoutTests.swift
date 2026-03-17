import CoreGraphics
import Testing
@testable import SpacesNavigation

struct WorkspaceLayoutTests {
    @Test
    func focusesPreviousAndNextColumn() {
        var state = sampleState()

        state.perform(.focusNextColumn)
        #expect(state.activeColumnIndex == 1)

        state.perform(.focusPreviousColumn)
        #expect(state.activeColumnIndex == 0)
    }

    @Test
    func focusesRowsWithinColumn() {
        var state = sampleState()

        state.perform(.focusRowDown)
        #expect(state.activeRowIndex == 1)

        state.perform(.focusRowUp)
        #expect(state.activeRowIndex == 0)
    }

    @Test
    func zoomWorkspaceCommandsStepInTenPercentIntervals() {
        var state = sampleState()
        let firstRowIndex = state.activeRowIndex

        state.perform(.zoomWorkspaceOut)
        #expect(abs(state.rowHeightScale(for: firstRowIndex) - 0.9) < 0.0001)

        state.perform(.zoomWorkspaceIn)
        #expect(abs(state.rowHeightScale(for: firstRowIndex) - 1.0) < 0.0001)

        for _ in 0..<10 {
            state.perform(.zoomWorkspaceOut)
        }
        #expect(abs(state.rowHeightScale(for: firstRowIndex) - 0.3) < 0.0001)

        for _ in 0..<10 {
            state.perform(.zoomWorkspaceIn)
        }
        #expect(abs(state.rowHeightScale(for: firstRowIndex) - 1.0) < 0.0001)
        #expect(abs(state.rowHeightScale(for: 1) - 1.0) < 0.0001)
    }

    @Test
    func focusedPaneWidthCommandsStepInTenPercentIntervals() {
        var state = sampleState()
        let focusedRowID = state.focus.rowID

        state.perform(.widenFocusedPane)
        #expect(abs(state.paneWidthScale(for: focusedRowID) - 1.1) < 0.0001)

        state.perform(.shrinkFocusedPane)
        #expect(abs(state.paneWidthScale(for: focusedRowID) - 1.0) < 0.0001)

        for _ in 0..<10 {
            state.perform(.shrinkFocusedPane)
        }
        #expect(abs(state.paneWidthScale(for: focusedRowID) - 0.5) < 0.0001)

        for _ in 0..<10 {
            state.perform(.widenFocusedPane)
        }
        #expect(abs(state.paneWidthScale(for: focusedRowID) - 1.5) < 0.0001)
    }

    @Test
    func insertsPaneToTheRightOfActiveColumn() {
        var state = sampleState()
        let startingColumn = state.columns[0].id

        state.perform(.createPane)

        #expect(state.columns.count == 4)
        #expect(state.columns[0].id == startingColumn)
        #expect(state.activeColumnIndex == 1)
    }

    @Test
    func movesColumnLeftAndRight() {
        var state = sampleState()
        state.perform(.focusNextColumn)
        let movedColumnID = state.focus.columnID

        state.perform(.moveColumnRight)
        #expect(state.columns[2].id == movedColumnID)

        state.perform(.moveColumnLeft)
        #expect(state.columns[1].id == movedColumnID)
    }

    @Test
    func centersViewportOnActiveColumn() {
        let engine = WorkspaceLayoutEngine(metrics: WorkspaceLayoutMetrics(interColumnSpacing: 20, defaultColumnWidth: 600))
        var state = sampleState()
        state.perform(.focusNextColumn)

        let snapshot = engine.snapshot(for: state, viewportSize: CGSize(width: 1000, height: 800))
        let activeLane = try! #require(snapshot.lanes.first(where: { $0.id == state.activeRowIndex }))
        let activeSpace = try! #require(activeLane.spaces.first(where: { $0.id == state.focus.rowID }))

        #expect(abs((activeSpace.rect.midX - activeLane.contentOffsetX) - 500) < 0.5)
    }

    @Test
    func focusingDeeperRowsMovesViewportDownward() {
        let engine = WorkspaceLayoutEngine(metrics: WorkspaceLayoutMetrics(interRowSpacing: 0))
        let state = sampleState()

        let snapshot = engine.snapshot(for: state, viewportSize: CGSize(width: 1200, height: 400))
        let firstLane = try! #require(snapshot.lanes.first)

        #expect(snapshot.contentRect.height > 400)
        #expect(snapshot.contentOffsetY == 0)
        #expect(firstLane.frame.minY == 0)
        #expect(firstLane.frame.height == 400)
        #expect(snapshot.lanes.last?.frame.minY == 800)
    }

    @Test
    func activeRowIsCenteredWhenMovingDown() {
        let engine = WorkspaceLayoutEngine(metrics: WorkspaceLayoutMetrics(interRowSpacing: 0))
        var state = sampleState()

        state.perform(.focusRowDown)

        let snapshot = engine.snapshot(for: state, viewportSize: CGSize(width: 1200, height: 400))
        let activeLane = try! #require(snapshot.lanes.first(where: { $0.id == state.activeRowIndex }))
        let activeRow = try! #require(activeLane.spaces.first(where: { $0.id == state.focus.rowID }))

        let visibleMidY = activeLane.frame.minY + activeRow.rect.midY
        #expect(abs(visibleMidY - 200) < 0.5)
        #expect(abs(activeRow.rect.height - 344) < 0.5)
    }

    @Test
    func manyPanesOverflowHorizontallyInsteadOfShrinkingEverything() {
        let engine = WorkspaceLayoutEngine(metrics: WorkspaceLayoutMetrics(interColumnSpacing: 24, defaultColumnWidth: 640))
        let columns = (0..<8).map { index in
            WorkspaceColumn(width: 640, rows: [WorkspaceRow(title: "Pane \(index)")])
        }
        let state = WorkspaceState(columns: columns)

        let snapshot = engine.snapshot(for: state, viewportSize: CGSize(width: 1200, height: 700))

        #expect(snapshot.contentRect.width > 1200)
        #expect(snapshot.lanes.allSatisfy { lane in lane.spaces.allSatisfy { abs($0.rect.width - 800) < 0.5 } })
    }

    @Test
    func focusedSpaceIsNotZoomedInStandardMode() {
        let engine = WorkspaceLayoutEngine(metrics: WorkspaceLayoutMetrics(defaultColumnWidth: 640, zoomedColumnWidthFraction: 0.92))
        let state = sampleState()

        let snapshot = engine.snapshot(for: state, viewportSize: CGSize(width: 1400, height: 800))
        let activeLane = try! #require(snapshot.lanes.first(where: { $0.id == state.activeRowIndex }))
        let activeRow = try! #require(activeLane.spaces.first(where: { $0.id == state.focus.rowID }))

        #expect(abs(activeRow.rect.width - (1400 * (2.0 / 3.0))) < 0.5)
    }

    @Test
    func rowsUsePeekHeightsAtTopMiddleAndBottom() {
        let engine = WorkspaceLayoutEngine(metrics: WorkspaceLayoutMetrics(verticalRowPeek: 30))
        let state = sampleState()

        let snapshot = engine.snapshot(for: state, viewportSize: CGSize(width: 1400, height: 800))
        let topLane = try! #require(snapshot.lanes.first(where: { $0.id == 0 }))
        let middleLane = try! #require(snapshot.lanes.first(where: { $0.id == 1 }))
        let bottomLane = try! #require(snapshot.lanes.first(where: { $0.id == 2 }))
        let topRow = try! #require(topLane.spaces.first)
        let middleRow = try! #require(middleLane.spaces.first)
        let bottomRow = try! #require(bottomLane.spaces.first)

        #expect(topRow.rect.minY == 0)
        #expect(abs(topRow.rect.height - 770) < 0.5)
        #expect(abs(middleRow.rect.minY - 30) < 0.5)
        #expect(abs(middleRow.rect.height - 740) < 0.5)
        #expect(abs(bottomRow.rect.minY - 30) < 0.5)
        #expect(abs(bottomRow.rect.height - 770) < 0.5)
    }

    @Test
    func focusedExpandedSpaceFillsTheViewport() {
        let engine = WorkspaceLayoutEngine(metrics: WorkspaceLayoutMetrics(defaultColumnWidth: 640, zoomedColumnWidthFraction: 0.92))
        var state = sampleState()
        state.perform(.toggleZoom)

        let snapshot = engine.snapshot(for: state, viewportSize: CGSize(width: 1400, height: 800))
        let activeLane = try! #require(snapshot.lanes.first(where: { $0.id == state.activeRowIndex }))
        let activeRow = try! #require(activeLane.spaces.first(where: { $0.id == state.focus.rowID }))

        #expect(activeLane.contentOffsetX == 0)
        #expect(activeRow.rect.minX == 0)
        #expect(activeRow.rect.minY == 0)
        #expect(abs(activeRow.rect.width - 1400) < 0.5)
        #expect(abs(activeRow.rect.height - 800) < 0.5)
        let siblingRow = try! #require(activeLane.spaces.first(where: { $0.id != state.focus.rowID }))
        #expect(abs(siblingRow.rect.width - (1400 * (2.0 / 3.0))) < 0.5)
    }

    @Test
    func singlePaneRowFillsTheViewportWithoutZoom() {
        let engine = WorkspaceLayoutEngine(metrics: WorkspaceLayoutMetrics(defaultColumnWidth: 640, verticalRowPeek: 30))
        let columns = [
            WorkspaceColumn(width: 720, rows: [
                WorkspaceRow(title: "1a"),
                WorkspaceRow(title: "2a")
            ]),
            WorkspaceColumn(width: 720, rows: [
                WorkspaceRow(title: "1b")
            ])
        ]
        let focus = WorkspaceFocus(columnID: columns[0].id, rowID: columns[0].rows[0].id)
        let state = WorkspaceState(columns: columns, focus: focus)

        let snapshot = engine.snapshot(for: state, viewportSize: CGSize(width: 1400, height: 800))
        let secondLane = try! #require(snapshot.lanes.first(where: { $0.id == 1 }))
        let onlyRow = try! #require(secondLane.spaces.first)

        #expect(secondLane.contentOffsetX == 0)
        #expect(onlyRow.rect.minX == 0)
        #expect(onlyRow.rect.minY == 0)
        #expect(abs(onlyRow.rect.width - 1400) < 0.5)
        #expect(abs(onlyRow.rect.height - 800) < 0.5)
    }

    @Test
    func overviewModeShowsSmallerRowsAndPanes() {
        let engine = WorkspaceLayoutEngine(metrics: WorkspaceLayoutMetrics(defaultColumnWidth: 640))
        var state = sampleState()
        for _ in 0..<7 {
            state.perform(.zoomWorkspaceOut)
        }

        let snapshot = engine.snapshot(for: state, viewportSize: CGSize(width: 1400, height: 800))
        let topLane = try! #require(snapshot.lanes.first(where: { $0.id == 0 }))
        let topRow = try! #require(topLane.spaces.first(where: { $0.id == state.focus.rowID }))
        let lowerLane = try! #require(snapshot.lanes.first(where: { $0.id == 1 }))
        let lowerRow = try! #require(lowerLane.spaces.first)

        #expect(topLane.frame.height <= 320)
        #expect(lowerLane.frame.minY < 400)
        #expect(abs(topRow.rect.width - (1400 * (2.0 / 3.0))) < 0.5)
        #expect(lowerRow.rect.height > 320)
    }

    @Test
    func rowHeightsPersistIndependentlyAcrossNavigation() {
        let engine = WorkspaceLayoutEngine(metrics: WorkspaceLayoutMetrics(defaultColumnWidth: 640))
        var state = sampleState()

        state.perform(.zoomWorkspaceOut)
        state.perform(.zoomWorkspaceOut)
        #expect(abs(state.rowHeightScale(for: 0) - 0.8) < 0.0001)

        state.perform(.focusRowDown)
        state.perform(.zoomWorkspaceOut)
        #expect(abs(state.rowHeightScale(for: 1) - 0.9) < 0.0001)

        state.perform(.focusRowUp)

        let snapshot = engine.snapshot(for: state, viewportSize: CGSize(width: 1400, height: 800))
        let firstLane = try! #require(snapshot.lanes.first(where: { $0.id == 0 }))
        let secondLane = try! #require(snapshot.lanes.first(where: { $0.id == 1 }))
        let firstRow = try! #require(firstLane.spaces.first)
        let secondRow = try! #require(secondLane.spaces.first)

        #expect(abs(firstLane.frame.height - 640) < 0.5)
        #expect(abs(firstRow.rect.height - 612) < 0.5)
        #expect(abs(secondLane.frame.height - 720) < 0.5)
        #expect(abs(secondRow.rect.height - 664) < 0.5)
    }

    @Test
    func closingLastPaneInRowRemovesPersistedRowHeightState() {
        var state = WorkspaceState(columns: [
            WorkspaceColumn(rows: [
                WorkspaceRow(title: "1a"),
                WorkspaceRow(title: "2a")
            ]),
            WorkspaceColumn(rows: [
                WorkspaceRow(title: "1b")
            ])
        ])

        state.perform(.focusRowDown)
        state.perform(.zoomWorkspaceOut)
        #expect(abs(state.rowHeightScale(for: 1) - 0.9) < 0.0001)

        state.perform(.closeActivePane)

        #expect(state.rowHeightScaleByRowIndex[1] == nil)
    }

    @Test
    func wideningFocusedPaneOnlyChangesFocusedPaneWidth() {
        let engine = WorkspaceLayoutEngine(metrics: WorkspaceLayoutMetrics(defaultColumnWidth: 640))
        var state = sampleState()

        state.perform(.widenFocusedPane)

        let snapshot = engine.snapshot(for: state, viewportSize: CGSize(width: 1400, height: 800))
        let lane = try! #require(snapshot.lanes.first(where: { $0.id == state.activeRowIndex }))
        let focusedRow = try! #require(lane.spaces.first(where: { $0.id == state.focus.rowID }))
        let siblingRow = try! #require(lane.spaces.first(where: { $0.id != state.focus.rowID }))

        #expect(abs(focusedRow.rect.width - ((1400 * (2.0 / 3.0)) * 1.1)) < 0.5)
        #expect(abs(siblingRow.rect.width - (1400 * (2.0 / 3.0))) < 0.5)
    }

    @Test
    func paneWidthsPersistIndependentlyAcrossNavigation() {
        let engine = WorkspaceLayoutEngine(metrics: WorkspaceLayoutMetrics(defaultColumnWidth: 640))
        var state = sampleState()
        let firstRowID = state.focus.rowID

        state.perform(.widenFocusedPane)
        state.perform(.focusNextColumn)
        let secondRowID = state.focus.rowID
        state.perform(.shrinkFocusedPane)

        #expect(abs(state.paneWidthScale(for: firstRowID) - 1.1) < 0.0001)
        #expect(abs(state.paneWidthScale(for: secondRowID) - 0.9) < 0.0001)

        state.perform(.focusPreviousColumn)

        let snapshot = engine.snapshot(for: state, viewportSize: CGSize(width: 1400, height: 800))
        let lane = try! #require(snapshot.lanes.first(where: { $0.id == state.activeRowIndex }))
        let firstRow = try! #require(lane.spaces.first(where: { $0.id == firstRowID }))
        let secondRow = try! #require(lane.spaces.first(where: { $0.id == secondRowID }))

        #expect(abs(firstRow.rect.width - ((1400 * (2.0 / 3.0)) * 1.1)) < 0.5)
        #expect(abs(secondRow.rect.width - ((1400 * (2.0 / 3.0)) * 0.9)) < 0.5)
    }

    @Test
    func closingPaneRemovesPersistedPaneWidthState() {
        var state = sampleState()
        let rowIDToClose = state.focus.rowID

        state.perform(.widenFocusedPane)
        #expect(abs(state.paneWidthScale(for: rowIDToClose) - 1.1) < 0.0001)

        state.perform(.closeActivePane)

        #expect(state.paneWidthScaleByRowID[rowIDToClose] == nil)
    }

    @Test
    func zoomPersistsAcrossNavigation() {
        var state = sampleState()
        let zoomedRowID = state.focus.rowID

        state.perform(.toggleZoom)
        #expect(state.viewportMode == .expandedSpaces([zoomedRowID]))

        state.perform(.focusNextColumn)
        #expect(state.viewportMode == .expandedSpaces([zoomedRowID]))

        state.perform(.focusPreviousColumn)
        #expect(state.viewportMode == .expandedSpaces([zoomedRowID]))
    }

    @Test
    func expandedSpaceRemainsExpandedWhenFocusMoves() {
        let engine = WorkspaceLayoutEngine(metrics: WorkspaceLayoutMetrics(defaultColumnWidth: 640, zoomedColumnWidthFraction: 0.92))
        var state = sampleState()
        let originalFocus = state.focus

        state.perform(.toggleZoom)
        state.perform(.focusNextColumn)

        let snapshot = engine.snapshot(for: state, viewportSize: CGSize(width: 1400, height: 800))
        let focusedLane = try! #require(snapshot.lanes.first(where: { $0.id == state.activeRowIndex }))
        let focusedRow = try! #require(focusedLane.spaces.first(where: { $0.id == state.focus.rowID }))
        let originalLane = try! #require(snapshot.lanes.first(where: { lane in lane.spaces.contains(where: { $0.id == originalFocus.rowID }) }))
        let originalRow = try! #require(originalLane.spaces.first(where: { $0.id == originalFocus.rowID }))

        #expect(abs(originalRow.rect.width - 1288) < 0.5)
        #expect(abs(focusedRow.rect.width - (1400 * (2.0 / 3.0))) < 0.5)
    }

    @Test
    func expandedSpaceRemainsExpandedWhenMovingVertically() {
        let engine = WorkspaceLayoutEngine(metrics: WorkspaceLayoutMetrics(defaultColumnWidth: 640, zoomedColumnWidthFraction: 0.92))
        var state = sampleState()
        let originalFocus = state.focus

        state.perform(.toggleZoom)
        state.perform(.focusRowDown)

        let snapshot = engine.snapshot(for: state, viewportSize: CGSize(width: 1400, height: 800))
        let activeLane = try! #require(snapshot.lanes.first(where: { $0.id == state.activeRowIndex }))
        let activeRow = try! #require(activeLane.spaces.first(where: { $0.id == state.focus.rowID }))
        let originalLane = try! #require(snapshot.lanes.first(where: { lane in lane.spaces.contains(where: { $0.id == originalFocus.rowID }) }))
        let originalRow = try! #require(originalLane.spaces.first(where: { $0.id == originalFocus.rowID }))

        #expect(abs(activeRow.rect.width - (1400 * (2.0 / 3.0))) < 0.5)
        #expect(abs(originalRow.rect.width - 1288) < 0.5)
    }

    @Test
    func multipleSpacesCanRemainExpanded() {
        let engine = WorkspaceLayoutEngine(metrics: WorkspaceLayoutMetrics(defaultColumnWidth: 640, zoomedColumnWidthFraction: 0.92))
        var state = sampleState()
        let firstExpandedID = state.focus.rowID

        state.perform(.toggleZoom)
        state.perform(.focusNextColumn)
        let secondExpandedID = state.focus.rowID
        state.perform(.toggleZoom)

        let snapshot = engine.snapshot(for: state, viewportSize: CGSize(width: 1400, height: 800))
        let lane = try! #require(snapshot.lanes.first(where: { $0.id == 0 }))
        let firstRow = try! #require(lane.spaces.first(where: { $0.id == firstExpandedID }))
        let secondRow = try! #require(lane.spaces.first(where: { $0.id == secondExpandedID }))

        #expect(abs(firstRow.rect.width - (1400 * (2.0 / 3.0))) < 0.5)
        #expect(secondRow.rect.minX == 0)
        #expect(abs(secondRow.rect.width - 1400) < 0.5)
    }

    @Test
    func rowsRememberIndependentHorizontalPositions() {
        var state = sampleState()

        state.perform(.focusNextColumn)
        state.perform(.focusNextColumn)
        #expect(state.focus.columnID == state.columns[2].id)
        #expect(state.focus.rowID == state.columns[2].rows[0].id)

        state.perform(.focusRowDown)
        #expect(state.focus.columnID == state.columns[0].id)
        #expect(state.focus.rowID == state.columns[0].rows[1].id)

        state.perform(.focusRowUp)
        #expect(state.focus.columnID == state.columns[2].id)
        #expect(state.focus.rowID == state.columns[2].rows[0].id)
    }

    @Test
    func rowLanesKeepIndependentHorizontalOffsets() {
        let engine = WorkspaceLayoutEngine(metrics: WorkspaceLayoutMetrics(defaultColumnWidth: 640))
        let columns = [
            WorkspaceColumn(width: 640, rows: [WorkspaceRow(title: "1a"), WorkspaceRow(title: "2a")]),
            WorkspaceColumn(width: 640, rows: [WorkspaceRow(title: "1b"), WorkspaceRow(title: "2b")]),
            WorkspaceColumn(width: 640, rows: [WorkspaceRow(title: "1c"), WorkspaceRow(title: "2c")])
        ]
        let focus = WorkspaceFocus(columnID: columns[0].id, rowID: columns[0].rows[0].id)
        let state = WorkspaceState(
            columns: columns,
            focus: focus,
            rememberedColumnByRowIndex: [
                0: columns[0].id,
                1: columns[2].id
            ]
        )

        let snapshot = engine.snapshot(for: state, viewportSize: CGSize(width: 1200, height: 800))
        let topLane = try! #require(snapshot.lanes.first(where: { $0.id == 0 }))
        let bottomLane = try! #require(snapshot.lanes.first(where: { $0.id == 1 }))

        #expect(topLane.contentOffsetX == 0)
        #expect(bottomLane.contentOffsetX > 0)
    }

    @Test
    func laneScrollTargetsFollowRememberedHorizontalPosition() {
        let engine = WorkspaceLayoutEngine(metrics: WorkspaceLayoutMetrics(defaultColumnWidth: 640))
        let columns = [
            WorkspaceColumn(width: 640, rows: [WorkspaceRow(title: "1a"), WorkspaceRow(title: "2a")]),
            WorkspaceColumn(width: 640, rows: [WorkspaceRow(title: "1b"), WorkspaceRow(title: "2b")]),
            WorkspaceColumn(width: 640, rows: [WorkspaceRow(title: "1c"), WorkspaceRow(title: "2c")])
        ]
        let focus = WorkspaceFocus(columnID: columns[0].id, rowID: columns[0].rows[0].id)
        let state = WorkspaceState(
            columns: columns,
            focus: focus,
            rememberedColumnByRowIndex: [
                0: columns[1].id,
                1: columns[2].id
            ]
        )

        let snapshot = engine.snapshot(for: state, viewportSize: CGSize(width: 1200, height: 800))
        let topLane = try! #require(snapshot.lanes.first(where: { $0.id == 0 }))
        let bottomLane = try! #require(snapshot.lanes.first(where: { $0.id == 1 }))

        #expect(topLane.scrollTargetSpaceID == columns[0].rows[0].id)
        #expect(bottomLane.scrollTargetSpaceID == columns[2].rows[1].id)
    }

    @Test
    func activeLaneIDMatchesFocusedRowForVerticalScrolling() {
        let engine = WorkspaceLayoutEngine()
        var state = sampleState()

        state.perform(.focusRowDown)
        let snapshot = engine.snapshot(for: state, viewportSize: CGSize(width: 1200, height: 800))

        #expect(snapshot.activeLaneID == 1)
        #expect(snapshot.lanes.first(where: { $0.id == 1 })?.scrollTargetSpaceID == state.focus.rowID)
    }

    @Test
    func closingPaneDoesNotPromoteLowerRowsIntoItsLane() {
        var state = WorkspaceState(columns: [
            WorkspaceColumn(rows: [
                WorkspaceRow(title: "A1"),
                WorkspaceRow(title: "A2"),
                WorkspaceRow(title: "A3")
            ]),
            WorkspaceColumn(rows: [
                WorkspaceRow(title: "B1"),
                WorkspaceRow(title: "B2")
            ])
        ])

        let secondRowID = try! #require(state.columns[0].row(atLaneIndex: 1)?.id)
        let thirdRowID = try! #require(state.columns[0].row(atLaneIndex: 2)?.id)
        state.focus = WorkspaceFocus(columnID: state.columns[0].id, rowID: secondRowID)

        state.perform(.closeActivePane)

        #expect(state.columns[0].row(atLaneIndex: 1) == nil)
        #expect(state.columns[0].row(atLaneIndex: 2)?.id == thirdRowID)
        #expect(state.focus.rowID == state.columns[1].row(atLaneIndex: 1)?.id)
    }
}

private func sampleState() -> WorkspaceState {
    WorkspaceState(columns: [
        WorkspaceColumn(rows: [
            WorkspaceRow(title: "A1"),
            WorkspaceRow(title: "A2"),
            WorkspaceRow(title: "A3")
        ]),
        WorkspaceColumn(rows: [
            WorkspaceRow(title: "B1"),
            WorkspaceRow(title: "B2"),
            WorkspaceRow(title: "B3")
        ]),
        WorkspaceColumn(rows: [
            WorkspaceRow(title: "C1")
        ])
    ])
}
