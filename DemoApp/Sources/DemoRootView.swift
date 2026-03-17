import SwiftUI
import SpacesNavigation

struct DemoRootView: View {
    private static let demoLayoutEngine = WorkspaceLayoutEngine(
        metrics: WorkspaceLayoutMetrics(
            interColumnSpacing: 0,
            interRowSpacing: 0,
            verticalRowPeek: 0
        )
    )

    @Bindable var store: WorkspaceStore
    @State private var rowNames: [Int: String] = [:]
    @State private var editingRowID: Int?
    @State private var editingName = ""

    var body: some View {
        NavigationSplitView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    Text("Rows")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 6)

                    ForEach(rowSummaries) { summary in
                        SidebarRow(
                            summary: summary,
                            isEditing: editingRowID == summary.id,
                            editingName: editingRowID == summary.id ? editingName : summary.title,
                            onSelect: {
                                store.focusRowIndex(summary.id)
                            },
                            onBeginEditing: {
                                editingRowID = summary.id
                                editingName = summary.title
                            },
                            onEditingNameChange: { editingName = $0 },
                            onCommitEditing: {
                                renameRow(summary.id, to: editingName)
                                editingRowID = nil
                                editingName = ""
                            },
                            onCancelEditing: {
                                editingRowID = nil
                                editingName = ""
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
            }
            .navigationTitle("Rows")
            .frame(minWidth: 220)
        } detail: {
            WorkspaceView(store: store, layoutEngine: Self.demoLayoutEngine) { column, row, isFocused in
                DemoPane(isFocused: isFocused) {
                    DemoTerminalSurface(
                        rowName: rowName(for: row.laneIndex),
                        column: column,
                        row: row,
                        isFocused: isFocused
                    )
                }
            }
            .modifier(SystemWorkspaceDetailPresentation())
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var rowSummaries: [RowSummary] {
        (0..<store.state.maxRowCount).compactMap { rowIndex in
            let lane = store.state.columns(forRowIndex: rowIndex)
            guard !lane.isEmpty else { return nil }
            let titles = lane.compactMap { column in
                column.row(atLaneIndex: rowIndex)?.title
            }
            return RowSummary(
                id: rowIndex,
                title: rowName(for: rowIndex),
                subtitle: titles.joined(separator: "  |  "),
                isSelected: rowIndex == store.state.activeRowIndex
            )
        }
    }

    private func rowName(for rowIndex: Int) -> String {
        let trimmed = rowNames[rowIndex]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false ? trimmed : nil) ?? "Row \(rowIndex + 1)"
    }

    private func renameRow(_ rowIndex: Int, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        rowNames[rowIndex] = trimmed.isEmpty ? "Row \(rowIndex + 1)" : trimmed
    }
}

private struct RowSummary: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let isSelected: Bool
}

private struct SidebarRow: View {
    @FocusState private var isEditorFocused: Bool

    let summary: RowSummary
    let isEditing: Bool
    let editingName: String
    let onSelect: () -> Void
    let onBeginEditing: () -> Void
    let onEditingNameChange: (String) -> Void
    let onCommitEditing: () -> Void
    let onCancelEditing: () -> Void

    var body: some View {
        let editingBinding = Binding(
            get: { editingName },
            set: { onEditingNameChange($0) }
        )

        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(summary.id + 1)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(summary.isSelected ? .white.opacity(0.92) : .secondary)
                .frame(width: 22, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                if isEditing {
                    TextField("Row Name", text: editingBinding)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, weight: .semibold))
                        .focused($isEditorFocused)
                        .onSubmit(onCommitEditing)
                        .onExitCommand(perform: onCancelEditing)
                        .onAppear {
                            isEditorFocused = true
                        }
                } else {
                    Text(summary.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(summary.isSelected ? .white : .primary)
                        .lineLimit(1)
                }

                Text(summary.subtitle)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(summary.isSelected ? .white.opacity(0.78) : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)

            Spacer(minLength: 8)

            Button(action: onBeginEditing) {
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(summary.isSelected ? .white.opacity(0.88) : .secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(summary.isSelected ? Color.white.opacity(0.12) : Color.primary.opacity(0.05))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selectionBackground)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if summary.isSelected {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.92),
                            Color.accentColor.opacity(0.76)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.clear)
        }
    }
}

private struct DemoPane<Content: View>: View {
    let isFocused: Bool
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(isFocused ? Color.accentColor.opacity(0.08) : Color.black.opacity(0.18))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(isFocused ? Color.accentColor.opacity(0.45) : Color.white.opacity(0.12), lineWidth: isFocused ? 1.5 : 1)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct DemoTerminalSurface: View {
    let rowName: String
    let column: WorkspaceColumn
    let row: WorkspaceRow
    let isFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rowName)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isFocused ? Color.accentColor.opacity(0.95) : Color.white.opacity(0.96))

                    Text(row.title)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.62))
                }

                ForEach(WorkspaceDemoContent.terminalLines.indices, id: \.self) { index in
                    Text("\(column.id.uuidString.prefix(4)) \(row.title) [\(index + 1)] \(WorkspaceDemoContent.terminalLines[index])")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .modifier(SystemExtendingScrollBehavior())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SystemWorkspaceDetailPresentation: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .backgroundExtensionEffect()
                .background(Color.clear)
        } else {
            content
                .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

private struct SystemExtendingScrollBehavior: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .scrollClipDisabled()
                .backgroundExtensionEffect()
                .scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            content
                .scrollClipDisabled()
        }
    }
}
