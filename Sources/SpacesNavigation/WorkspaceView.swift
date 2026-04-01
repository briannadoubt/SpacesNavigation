import SwiftUI

public struct WorkspaceView<RowContent: View>: View {
    @Bindable private var store: WorkspaceStore
    private let layoutEngine: WorkspaceLayoutEngine
    private let rowContent: (WorkspaceColumn, WorkspaceRow, Bool) -> RowContent
    @State private var hasAppeared = false

    public init(
        store: WorkspaceStore,
        layoutEngine: WorkspaceLayoutEngine = WorkspaceLayoutEngine(),
        @ViewBuilder rowContent: @escaping (WorkspaceColumn, WorkspaceRow, Bool) -> RowContent
    ) {
        self.store = store
        self.layoutEngine = layoutEngine
        self.rowContent = rowContent
    }

    public var body: some View {
        GeometryReader { proxy in
            if store.state.columns.isEmpty {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let snapshot = layoutEngine.snapshot(for: store.state, viewportSize: proxy.size)
                let contentLookup = WorkspaceContentLookup(columns: store.state.columns)

                ScrollViewReader { verticalReader in
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: layoutEngine.metrics.interRowSpacing) {
                            ForEach(snapshot.lanes) { lane in
                                WorkspaceLaneScrollView(
                                    lane: lane,
                                    contentLookup: contentLookup,
                                    rowContent: rowContent
                                )
                                .id(lane.id)
                                .frame(height: max(lane.contentFrame.height, 0))
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .scrollDisabled(true)
                    .clipped()
                    .onAppear {
                        hasAppeared = true
                        WorkspacePerformanceSignpost.emit(
                            WorkspacePerformancePhase.verticalScrollRequest,
                            "phase=appear lane=\(snapshot.activeLaneID) animated=false offsetY=\(Int(snapshot.contentOffsetY.rounded()))"
                        )
                        scrollToActiveLane(with: verticalReader, snapshot: snapshot, animated: false)
                    }
                    .onChange(of: VerticalScrollKey(snapshot: snapshot)) { oldKey, key in
                        let interval = WorkspacePerformanceSignpost.begin(
                            WorkspacePerformancePhase.verticalScrollTask,
                            "lane=\(key.activeLaneID) offsetY=\(Int(key.contentOffsetY.rounded())) appeared=\(hasAppeared)"
                        )
                        var endMessage = "completed=false"
                        defer {
                            WorkspacePerformanceSignpost.end(interval, endMessage)
                        }
                        guard hasAppeared else {
                            endMessage = "skipped=notAppeared lane=\(key.activeLaneID)"
                            return
                        }
                        scrollToActiveLane(with: verticalReader, snapshot: snapshot, animated: false)
                        endMessage = "lane=\(key.activeLaneID) offsetY=\(Int(key.contentOffsetY.rounded())) animated=false priorLane=\(oldKey.activeLaneID)"
                    }
                }
            }
        }
    }

    private func scrollToActiveLane(
        with reader: ScrollViewProxy,
        snapshot: WorkspaceViewportSnapshot,
        animated: Bool
    ) {
        WorkspacePerformanceSignpost.emit(
            WorkspacePerformancePhase.verticalScrollRequest,
            "phase=commit lane=\(snapshot.activeLaneID) animated=\(animated) offsetY=\(Int(snapshot.contentOffsetY.rounded()))"
        )
        let action = {
            reader.scrollTo(snapshot.activeLaneID, anchor: .center)
        }

        action()
    }

    private struct VerticalScrollKey: Hashable {
        let activeLaneID: Int
        let contentOffsetY: CGFloat

        init(snapshot: WorkspaceViewportSnapshot) {
            activeLaneID = snapshot.activeLaneID
            contentOffsetY = snapshot.contentOffsetY
        }
    }
}

private struct WorkspaceContentLookup {
    private let columnsByID: [WorkspaceColumn.ID: WorkspaceColumn]
    private let rowsByID: [WorkspaceRow.ID: WorkspaceRow]

    init(columns: [WorkspaceColumn]) {
        columnsByID = Dictionary(uniqueKeysWithValues: columns.map { ($0.id, $0) })
        rowsByID = Dictionary(
            uniqueKeysWithValues: columns.flatMap { column in
                column.rows.map { ($0.id, $0) }
            }
        )
    }

    func resolve(space: WorkspaceSpacePresentation) -> (column: WorkspaceColumn, row: WorkspaceRow)? {
        guard let column = columnsByID[space.columnID],
              let row = rowsByID[space.id] else {
            return nil
        }

        return (column, row)
    }
}

private struct WorkspaceLaneScrollView<RowContent: View>: View {
    let lane: WorkspaceLanePresentation
    let contentLookup: WorkspaceContentLookup
    let rowContent: (WorkspaceColumn, WorkspaceRow, Bool) -> RowContent
    @State private var hasAppeared = false

    var body: some View {
        let spaceLayouts = laneSpaceLayouts
        ScrollViewReader { horizontalReader in
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 0) {
                    if leadingInset > 0 {
                        Color.clear
                            .frame(width: leadingInset)
                    }

                    ForEach(spaceLayouts) { item in
                        if let resolved = contentLookup.resolve(space: item.space) {
                            rowContent(resolved.column, resolved.row, item.space.isFocused)
                                .frame(
                                    width: max(item.space.rect.width, 0),
                                    height: max(item.space.rect.height, 0)
                                )
                                .id(item.space.id)
                                .zIndex(item.space.isFocused ? 2 : 0)

                            if item.spacingAfter > 0 {
                                Color.clear
                                    .frame(width: item.spacingAfter)
                            }
                        }
                    }

                    if trailingInset > 0 {
                        Color.clear
                            .frame(width: trailingInset)
                    }
                }
                .padding(.top, lane.topInset)
                .padding(.bottom, lane.bottomInset)
                .frame(width: max(lane.contentSize.width, 0), alignment: .leading)
            }
            .defaultScrollAnchor(.leading)
            .scrollIndicators(.hidden)
            .scrollDisabled(true)
            .onAppear {
                hasAppeared = true
                WorkspacePerformanceSignpost.emit(
                    WorkspacePerformancePhase.horizontalScrollRequest,
                    "phase=appear lane=\(lane.id) target=\(scrollTargetDescription) animated=false offsetX=\(Int(lane.contentOffsetX.rounded()))"
                )
            }
            .onChange(of: HorizontalScrollKey(lane: lane)) { oldKey, key in
                let interval = WorkspacePerformanceSignpost.begin(
                    WorkspacePerformancePhase.horizontalScrollTask,
                    "lane=\(lane.id) target=\(key.scrollTargetSpaceID?.uuidString ?? "nil") offsetX=\(Int(key.contentOffsetX.rounded())) appeared=\(hasAppeared)"
                )
                var endMessage = "completed=false"
                defer {
                    WorkspacePerformanceSignpost.end(interval, endMessage)
                }
                guard hasAppeared else {
                    endMessage = "skipped=notAppeared lane=\(lane.id)"
                    return
                }
                scrollToTarget(with: horizontalReader, animated: false)
                endMessage = "lane=\(lane.id) target=\(key.scrollTargetSpaceID?.uuidString ?? "nil") offsetX=\(Int(key.contentOffsetX.rounded())) animated=false priorTarget=\(oldKey.scrollTargetSpaceID?.uuidString ?? "nil")"
            }
        }
    }

    private var leadingInset: CGFloat {
        max(0, lane.spaces.first?.rect.minX ?? 0)
    }

    private var trailingInset: CGFloat {
        guard let last = lane.spaces.last else { return 0 }
        return max(0, lane.contentSize.width - last.rect.maxX)
    }

    private var scrollTargetDescription: String {
        lane.scrollTargetSpaceID?.uuidString ?? "nil"
    }

    private var laneSpaceLayouts: [LaneSpaceLayout] {
        lane.spaces.indices.map { index in
            let space = lane.spaces[index]
            let spacingAfter: CGFloat
            if index < lane.spaces.count - 1 {
                let next = lane.spaces[index + 1]
                spacingAfter = max(0, next.rect.minX - space.rect.maxX)
            } else {
                spacingAfter = 0
            }
            return LaneSpaceLayout(space: space, spacingAfter: spacingAfter)
        }
    }

    private func scrollToTarget(with reader: ScrollViewProxy, animated: Bool) {
        guard let target = lane.scrollTargetSpaceID else {
            WorkspacePerformanceSignpost.emit(
                WorkspacePerformancePhase.horizontalScrollRequest,
                "phase=skip lane=\(lane.id) reason=noTarget animated=\(animated)"
            )
            return
        }
        guard lane.contentSize.width > lane.frame.width + 1 else {
            WorkspacePerformanceSignpost.emit(
                WorkspacePerformancePhase.horizontalScrollRequest,
                "phase=skip lane=\(lane.id) reason=noOverflow animated=\(animated) width=\(Int(lane.contentSize.width.rounded())) frame=\(Int(lane.frame.width.rounded()))"
            )
            return
        }
        WorkspacePerformanceSignpost.emit(
            WorkspacePerformancePhase.horizontalScrollRequest,
            "phase=commit lane=\(lane.id) target=\(target.uuidString) animated=\(animated) offsetX=\(Int(lane.contentOffsetX.rounded()))"
        )
        let action = {
            reader.scrollTo(target, anchor: .center)
        }

        action()
    }

    private struct HorizontalScrollKey: Hashable {
        let scrollTargetSpaceID: WorkspaceRow.ID?
        let contentOffsetX: CGFloat

        init(lane: WorkspaceLanePresentation) {
            scrollTargetSpaceID = lane.scrollTargetSpaceID
            contentOffsetX = lane.contentOffsetX
        }
    }

    private struct LaneSpaceLayout: Identifiable {
        let space: WorkspaceSpacePresentation
        let spacingAfter: CGFloat

        var id: WorkspaceRow.ID {
            space.id
        }
    }
}

#Preview("Workspace Frames") {
    let store = WorkspaceStore(
        state: WorkspaceDemoContent.demoState()
    )

    return WorkspaceView(store: store) { _, row, isFocused in
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isFocused ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: isFocused ? 2 : 1)

            Text(row.title)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .padding(12)
        }
    }
    .padding()
    .background(Color(nsColor: .windowBackgroundColor))
    .frame(width: 1440, height: 900)
}
