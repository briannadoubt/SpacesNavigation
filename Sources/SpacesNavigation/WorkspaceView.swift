import SwiftUI

public struct WorkspaceView<RowContent: View>: View {
    @Bindable private var store: WorkspaceStore
    private let layoutEngine: WorkspaceLayoutEngine
    private let rowContent: (WorkspaceColumn, WorkspaceRow, Bool) -> RowContent
    @State private var hasAppeared = false

    private var verticalFocusScrollAnimation: Animation {
        .snappy(duration: 0.12, extraBounce: 0)
    }

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
                        scrollToActiveLane(with: verticalReader, snapshot: snapshot, animated: true)
                    }
                    .task(id: VerticalScrollKey(snapshot: snapshot)) {
                        let interval = WorkspacePerformanceSignpost.begin(
                            WorkspacePerformancePhase.verticalScrollTask,
                            "lane=\(snapshot.activeLaneID) offsetY=\(Int(snapshot.contentOffsetY.rounded())) appeared=\(hasAppeared)"
                        )
                        var endMessage = "completed=false"
                        defer {
                            WorkspacePerformanceSignpost.end(interval, endMessage)
                        }
                        guard hasAppeared else {
                            endMessage = "skipped=notAppeared lane=\(snapshot.activeLaneID)"
                            return
                        }
                        await Task.yield()
                        if Task.isCancelled {
                            endMessage = "cancelled=true lane=\(snapshot.activeLaneID)"
                            return
                        }
                        scrollToActiveLane(with: verticalReader, snapshot: snapshot, animated: true)
                        endMessage = "cancelled=false lane=\(snapshot.activeLaneID) offsetY=\(Int(snapshot.contentOffsetY.rounded()))"
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

        if animated {
            withAnimation(verticalFocusScrollAnimation) {
                action()
            }
        } else {
            action()
        }
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

    private var horizontalFocusScrollAnimation: Animation {
        .snappy(duration: 0.10, extraBounce: 0)
    }

    var body: some View {
        ScrollViewReader { horizontalReader in
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 0) {
                    if leadingInset > 0 {
                        Color.clear
                            .frame(width: leadingInset)
                    }

                    ForEach(lane.spaces) { space in
                        if let resolved = contentLookup.resolve(space: space) {
                            rowContent(resolved.column, resolved.row, space.isFocused)
                                .frame(
                                    width: max(space.rect.width, 0),
                                    height: max(space.rect.height, 0)
                                )
                                .id(space.id)
                                .zIndex(space.isFocused ? 2 : 0)

                            if space.id != lane.spaces.last?.id {
                                Color.clear
                                    .frame(width: spaceSpacing(after: space))
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
                scrollToTarget(with: horizontalReader, animated: true)
            }
            .onChange(of: HorizontalScrollKey(lane: lane)) { _, key in
                WorkspacePerformanceSignpost.emit(
                    WorkspacePerformancePhase.horizontalScrollTask,
                    "lane=\(lane.id) target=\(key.scrollTargetSpaceID?.uuidString ?? "nil") offsetX=\(Int(key.contentOffsetX.rounded())) appeared=\(hasAppeared)"
                )
                guard hasAppeared else { return }
                scrollToTarget(with: horizontalReader, animated: true)
            }
        }
    }

    private func spaceSpacing(after space: WorkspaceSpacePresentation) -> CGFloat {
        guard let index = lane.spaces.firstIndex(where: { $0.id == space.id }),
              index < lane.spaces.count - 1 else {
            return 0
        }
        let current = lane.spaces[index]
        let next = lane.spaces[index + 1]
        return max(0, next.rect.minX - current.rect.maxX)
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

        if animated {
            withAnimation(horizontalFocusScrollAnimation) {
                action()
            }
        } else {
            action()
        }
    }

    private struct HorizontalScrollKey: Hashable {
        let scrollTargetSpaceID: WorkspaceRow.ID?
        let contentOffsetX: CGFloat

        init(lane: WorkspaceLanePresentation) {
            scrollTargetSpaceID = lane.scrollTargetSpaceID
            contentOffsetX = lane.contentOffsetX
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
