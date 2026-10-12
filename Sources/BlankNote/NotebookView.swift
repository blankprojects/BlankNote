import AppKit
import SwiftUI
import BlankNoteCore

extension Notification.Name {
    static let blankNoteCommitEditing = Notification.Name("BlankNoteCommitEditing")
}

private func adaptive(_ light: NSColor, _ dark: NSColor) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
    })
}

let paper = adaptive(NSColor(red: 0.98, green: 0.97, blue: 0.94, alpha: 1), NSColor(red: 0.13, green: 0.15, blue: 0.14, alpha: 1))
private let ink = Color.primary
private let accent = adaptive(NSColor(red: 0.27, green: 0.40, blue: 0.32, alpha: 1), NSColor(red: 0.65, green: 0.80, blue: 0.65, alpha: 1))
private let card = adaptive(.white.withAlphaComponent(0.65), .white.withAlphaComponent(0.05))

struct NotebookView: View {
    @ObservedObject var store: NotebookStore
    @ObservedObject var state: WindowState
    @AppStorage("newTodoDraft") private var draft = ""
    @AppStorage("noteCollapsed") private var noteCollapsed = false
    @State private var showCompleted = false
    @State private var pendingDelete: TodoItem?
    @FocusState private var inputFocused: Bool

    private var remaining: Int { store.notebook.items.filter { !$0.completed }.count }
    private var completed: Int { store.notebook.items.filter { $0.completed }.count }
    private var visibleItems: [TodoItem] { store.notebook.items.filter { $0.completed == showCompleted } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if !state.collapsed {
                VStack(alignment: .leading, spacing: 12) {
                    input
                    HStack(spacing: 12) {
                        tab("待办", count: remaining, selected: !showCompleted) { showCompleted = false }
                        tab("已完成", count: completed, selected: showCompleted) { showCompleted = true }
                        Spacer()
                        if let title = store.undoTitle {
                            Button { commitEditing(); store.undo() } label: {
                                Image(systemName: "arrow.uturn.backward").font(.system(size: 12))
                            }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                            .help("撤销\(title)")
                            .accessibilityLabel("撤销\(title)")
                        }
                    }
                    .padding(.horizontal, 3)

                    ScrollView {
                        VStack(spacing: 7) {
                            if visibleItems.isEmpty { emptyState }
                            ForEach(visibleItems) { item in
                                TodoRow(item: item, store: store) { pendingDelete = item }
                                    .dropDestination(for: String.self) { strings, _ in
                                        reorder(strings, before: item.id)
                                    }
                            }
                            Color.clear.frame(height: 22)
                                .contentShape(Rectangle())
                                .accessibilityLabel("拖到列表末尾")
                                .dropDestination(for: String.self) { strings, _ in reorder(strings, before: nil) }
                        }
                    }
                    .frame(minHeight: 100, maxHeight: .infinity)

                    note
                    if let error = store.errorMessage {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.circle")
                            Text(error).textSelection(.enabled)
                            if store.hasUnsavedChanges {
                                Button("重试") { store.retrySave() }.buttonStyle(.plain)
                            }
                        }
                        .font(.system(size: 11)).foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(paper).foregroundStyle(ink)
        .preferredColorScheme(state.appearance.colorScheme)
        .onChange(of: state.focusRequest) { _, _ in inputFocused = true }
        .alert("删除这条待办？", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("取消", role: .cancel) { pendingDelete = nil }
            Button("删除", role: .destructive) {
                if let item = pendingDelete { store.remove(item.id) }
                pendingDelete = nil
            }
        } message: {
            Text("\(pendingDelete?.text ?? "")\n\n删除后可在本次使用期间撤销。")
        }
    }

    private var input: some View {
        HStack(spacing: 9) {
            Image(systemName: "plus").foregroundStyle(accent)
            TextField("记下一件事…", text: $draft)
                .textFieldStyle(.plain).focused($inputFocused)
                .onSubmit(addItem).accessibilityLabel("新待办")
            Button(action: addItem) {
                Image(systemName: "arrow.turn.down.left")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 24, height: 26)
            }
            .buttonStyle(.plain).foregroundStyle(accent)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help("添加待办（回车）").accessibilityLabel("添加待办")
        }
        .font(.system(size: 14)).padding(.horizontal, 12).padding(.vertical, 9)
        .background(card, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(accent.opacity(0.13)))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("BlankNote").font(.system(size: 15, weight: .semibold, design: .rounded))
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(context.date.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).month(.twoDigits).day(.twoDigits)))
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            Button { state.onPin?() } label: {
                Image(systemName: state.pinned ? "pin.fill" : "pin")
                    .rotationEffect(.degrees(35))
                    .foregroundStyle(state.pinned ? accent : .secondary)
                    .frame(width: 25, height: 26)
            }
            .buttonStyle(.plain).help(state.pinned ? "取消置顶" : "始终置顶")
            .accessibilityLabel(state.pinned ? "取消置顶" : "始终置顶")
            Button { state.onCollapse?() } label: {
                Image(systemName: state.collapsed ? "chevron.down" : "minus")
                    .foregroundStyle(.secondary).frame(width: 22, height: 26)
            }
            .buttonStyle(.plain).help(state.collapsed ? "展开便签" : "收起便签")
            .accessibilityLabel(state.collapsed ? "展开便签" : "收起便签")
        }
        .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 13)
    }

    private var note: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                commitEditing()
                noteCollapsed.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                    Text("随手记")
                    if noteCollapsed && !store.notebook.note.isEmpty {
                        Text(store.notebook.note.replacingOccurrences(of: "\n", with: " "))
                            .lineLimit(1).foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: noteCollapsed ? "chevron.right" : "chevron.down").font(.system(size: 9))
                }
                .font(.system(size: 11)).foregroundStyle(.secondary).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel(noteCollapsed ? "展开随手记" : "收起随手记")
            if !noteCollapsed {
                ZStack(alignment: .topLeading) {
                    if store.notebook.note.isEmpty {
                        Text("灵感，或一句备忘…").font(.system(size: 13)).foregroundStyle(.tertiary)
                            .padding(.horizontal, 5).padding(.top, 8).allowsHitTesting(false)
                    }
                    TextEditor(text: Binding(get: { store.notebook.note }, set: { store.setNote($0) }))
                        .font(.system(size: 13)).scrollContentBackground(.hidden)
                        .accessibilityLabel("随手记")
                }
                .frame(height: 88)
            }
        }
        .padding(11).background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private var emptyState: some View {
        VStack(spacing: 9) {
            Image(systemName: showCompleted ? "checkmark.circle" : "leaf")
                .font(.system(size: 25, weight: .light)).foregroundStyle(accent.opacity(0.6))
            Text(showCompleted ? "完成的事情，在这里" : "从一件小事开始")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 32)
    }

    private func tab(_ title: String, count: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { commitEditing(); action() } label: {
            Text("\(title) \(count)")
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? accent : .secondary)
                .padding(.vertical, 4)
        }.buttonStyle(.plain)
    }

    private func addItem() {
        commitEditing()
        if store.add(draft) { draft = ""; showCompleted = false; inputFocused = true }
    }

    private func commitEditing() { NotificationCenter.default.post(name: .blankNoteCommitEditing, object: nil) }

    private func reorder(_ strings: [String], before destination: UUID?) -> Bool {
        guard let value = strings.first, value.hasPrefix("blanknote:"),
              let id = UUID(uuidString: String(value.dropFirst("blanknote:".count))),
              store.notebook.items.contains(where: { $0.id == id && $0.completed == showCompleted }) else { return false }
        commitEditing()
        store.move(id, before: destination)
        return true
    }
}

private struct TodoRow: View {
    let item: TodoItem
    @ObservedObject var store: NotebookStore
    let onDelete: () -> Void
    @State private var editing = false
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 9)).foregroundStyle(.tertiary)
                .frame(width: 16, height: 20).contentShape(Rectangle())
                .help("拖动排序").accessibilityLabel("拖动排序：\(item.text)")
                .draggable("blanknote:\(item.id.uuidString)")
            Button { commit(); store.toggle(item.id) } label: {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .light)).foregroundStyle(accent.opacity(item.completed ? 1 : 0.5))
                    .frame(height: 20)
            }
            .buttonStyle(.plain).accessibilityLabel(item.completed ? "恢复待办：\(item.text)" : "完成：\(item.text)")
            if editing {
                TextField("待办内容", text: $text, axis: .vertical)
                    .textFieldStyle(.plain).font(.system(size: 14)).focused($focused)
                    .onSubmit(commit).onExitCommand { cancel() }
                    .onChange(of: focused) { _, value in if !value { commit() } }
                    .accessibilityLabel("编辑待办")
            } else {
                Text(item.text).font(.system(size: 14))
                    .strikethrough(item.completed).foregroundStyle(item.completed ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle()).onTapGesture(count: 2, perform: beginEdit)
            }
            Menu {
                Button("编辑", action: beginEdit)
                Button("删除…", role: .destructive) { commit(); onDelete() }
            } label: { Image(systemName: "ellipsis").foregroundStyle(.tertiary) }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 16)
            .accessibilityLabel("事项操作：\(item.text)")
        }
        .padding(.horizontal, 10).padding(.vertical, 11)
        .background(card, in: RoundedRectangle(cornerRadius: 10))
        .contextMenu {
            Button("编辑", action: beginEdit)
            Button("删除…", role: .destructive) { commit(); onDelete() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .blankNoteCommitEditing)) { _ in commit() }
    }

    private func beginEdit() { text = item.text; editing = true; focused = true }
    private func commit() {
        guard editing else { return }
        editing = false
        focused = false
        store.rename(item.id, text: text)
    }
    private func cancel() { editing = false; focused = false; text = item.text }
}
