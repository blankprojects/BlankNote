import Foundation
import Combine

public struct TodoItem: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var text: String
    public var completed = false
    public var createdAt = Date()
}

public struct Notebook: Codable, Equatable {
    public var items: [TodoItem] = []
    public var note = ""
}

public final class NotebookStore: ObservableObject {
    @Published public private(set) var notebook = Notebook()
    @Published public var errorMessage: String?
    @Published public private(set) var hasUnsavedChanges = false
    @Published public private(set) var undoTitle: String?
    @Published public private(set) var redoTitle: String?
    public let directory: URL
    private var canSave = true
    private struct HistoryEntry {
        let items: [TodoItem]
        let title: String
    }
    private var undoStack: [HistoryEntry] = []
    private var redoStack: [HistoryEntry] = []
    var file: URL { directory.appendingPathComponent("notebook.json") }
    var backup: URL { directory.appendingPathComponent("notebook.backup.json") }

    public init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("BlankNote", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: file.path) {
                do {
                    notebook = try JSONDecoder().decode(Notebook.self, from: Data(contentsOf: file))
                } catch {
                    if let recovered = try? JSONDecoder().decode(Notebook.self, from: Data(contentsOf: backup)) {
                        let preserved = self.directory.appendingPathComponent("notebook-unreadable-\(UUID().uuidString).json")
                        try FileManager.default.copyItem(at: file, to: preserved)
                        notebook = recovered
                        errorMessage = "已从备份恢复，原文件已保留。"
                    } else {
                        canSave = false
                        errorMessage = "数据暂时无法读取。已保护原文件，请从菜单栏打开数据文件夹检查。"
                    }
                }
            }
        } catch {
            canSave = false
            errorMessage = "无法打开数据文件夹：\(error.localizedDescription)"
        }
    }

    @discardableResult public func add(_ text: String) -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, canSave else { return false }
        changeItems("添加待办") { $0.append(TodoItem(text: clean)) }
        return true
    }

    public func toggle(_ id: UUID) {
        guard canSave, let index = notebook.items.firstIndex(where: { $0.id == id }) else { return }
        changeItems(notebook.items[index].completed ? "恢复待办" : "完成待办") { $0[index].completed.toggle() }
    }

    public func rename(_ id: UUID, text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSave, !clean.isEmpty, let index = notebook.items.firstIndex(where: { $0.id == id }) else { return }
        changeItems("编辑待办") { $0[index].text = clean }
    }

    public func remove(_ id: UUID) {
        guard canSave else { return }
        changeItems("删除待办") { $0.removeAll { $0.id == id } }
    }

    /// Reorder within a completion group, preserving the other group's positions.
    /// A nil destination moves the item to the end of its group.
    public func move(_ id: UUID, before destination: UUID?) {
        guard canSave, let item = notebook.items.first(where: { $0.id == id }), id != destination else { return }
        var group = notebook.items.filter { $0.completed == item.completed }
        guard destination == nil || group.contains(where: { $0.id == destination }) else { return }
        group.removeAll { $0.id == id }
        let target = destination.flatMap { target in group.firstIndex(where: { $0.id == target }) } ?? group.count
        group.insert(item, at: target)
        changeItems("调整顺序") { items in
            var next = 0
            for index in items.indices where items[index].completed == item.completed {
                items[index] = group[next]
                next += 1
            }
        }
    }

    public func undo() {
        guard canSave, let entry = undoStack.popLast() else { return }
        redoStack.append(HistoryEntry(items: notebook.items, title: entry.title))
        notebook.items = entry.items
        updateHistoryTitles()
        save()
    }

    public func redo() {
        guard canSave, let entry = redoStack.popLast() else { return }
        undoStack.append(HistoryEntry(items: notebook.items, title: entry.title))
        notebook.items = entry.items
        updateHistoryTitles()
        save()
    }

    private func changeItems(_ title: String, edit: (inout [TodoItem]) -> Void) {
        let old = notebook.items
        var next = old
        edit(&next)
        guard next != old else { return }
        undoStack.append(HistoryEntry(items: old, title: title))
        if undoStack.count > 50 { undoStack.removeFirst() }
        redoStack.removeAll()
        notebook.items = next
        updateHistoryTitles()
        save()
    }

    private func updateHistoryTitles() {
        undoTitle = undoStack.last?.title
        redoTitle = redoStack.last?.title
    }

    public func setNote(_ text: String) {
        guard canSave, notebook.note != text else { return }
        notebook.note = text
        save()
    }

    private func save() {
        hasUnsavedChanges = true
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(notebook)
            if let old = try? Data(contentsOf: file), (try? JSONDecoder().decode(Notebook.self, from: old)) != nil {
                try old.write(to: backup, options: .atomic)
            }
            try data.write(to: file, options: .atomic)
            errorMessage = nil
            hasUnsavedChanges = false
        } catch {
            errorMessage = "保存失败，请先不要退出：\(error.localizedDescription)"
        }
    }

    @discardableResult public func retrySave() -> Bool {
        guard canSave else { return false }
        if hasUnsavedChanges { save() }
        return !hasUnsavedChanges
    }
}
