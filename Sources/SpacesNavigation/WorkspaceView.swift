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

                ScrollViewReader { verticalReader in
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: layoutEngine.metrics.interRowSpacing) {
                            ForEach(snapshot.lanes) { lane in
                                WorkspaceLaneScrollView(
                                    lane: lane,
                                    store: store,
                                    rowContent: rowContent
                                )
                                .id(lane.id)
                                .frame(height: max(lane.contentFrame.height, 0))
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .clipped()
                    .onAppear {
                        hasAppeared = true
                        scrollToActiveLane(with: verticalReader, snapshot: snapshot, animated: false)
                    }
                    .task(id: VerticalScrollKey(snapshot: snapshot)) {
                        guard hasAppeared else { return }
                        await Task.yield()
                        scrollToActiveLane(with: verticalReader, snapshot: snapshot, animated: true)
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
        let action = {
            reader.scrollTo(snapshot.activeLaneID, anchor: .center)
        }

        if animated {
            withAnimation(.snappy(duration: 0.22)) {
                action()
            }
        } else {
            action()
        }
    }

    private struct VerticalScrollKey: Hashable {
        let activeLaneID: Int
        let contentHeight: CGFloat

        init(snapshot: WorkspaceViewportSnapshot) {
            activeLaneID = snapshot.activeLaneID
            contentHeight = snapshot.contentRect.height
        }
    }
}

private struct WorkspaceLaneScrollView<RowContent: View>: View {
    let lane: WorkspaceLanePresentation
    let store: WorkspaceStore
    let rowContent: (WorkspaceColumn, WorkspaceRow, Bool) -> RowContent
    @State private var hasAppeared = false

    var body: some View {
        ScrollViewReader { horizontalReader in
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 0) {
                    if leadingInset > 0 {
                        Color.clear
                            .frame(width: leadingInset)
                    }

                    ForEach(lane.spaces) { space in
                        if let modelColumn = store.state.columns.first(where: { $0.id == space.columnID }),
                           let row = modelColumn.rows.first(where: { $0.id == space.id }) {
                            rowContent(modelColumn, row, space.isFocused)
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
            .onAppear {
                hasAppeared = true
                scrollToTarget(with: horizontalReader, animated: false)
            }
            .task(id: HorizontalScrollKey(lane: lane)) {
                guard hasAppeared else { return }
                await Task.yield()
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

    private func scrollToTarget(with reader: ScrollViewProxy, animated: Bool) {
        guard let target = lane.scrollTargetSpaceID else { return }
        guard lane.contentSize.width > lane.frame.width + 1 else { return }
        let action = {
            reader.scrollTo(target, anchor: .leading)
        }

        if animated {
            withAnimation(.snappy(duration: 0.22)) {
                action()
            }
        } else {
            action()
        }
    }

    private struct HorizontalScrollKey: Hashable {
        let scrollTargetSpaceID: WorkspaceRow.ID?
        let focusedSpaceID: WorkspaceRow.ID?

        init(lane: WorkspaceLanePresentation) {
            scrollTargetSpaceID = lane.scrollTargetSpaceID
            focusedSpaceID = lane.focusedSpaceID
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
