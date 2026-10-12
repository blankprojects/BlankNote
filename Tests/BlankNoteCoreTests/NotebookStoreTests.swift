import XCTest
@testable import BlankNoteCore

final class NotebookStoreTests: XCTestCase {
    private func makeStore() -> NotebookStore {
        NotebookStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("BlankNoteTests-\(UUID().uuidString)"))
    }

    func testNewNotebookAndBlankInput() {
        let store = makeStore()
        XCTAssertTrue(store.notebook.items.isEmpty)
        XCTAssertEqual(store.notebook.note, "")
        XCTAssertFalse(store.add(" \n\t "))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.file.path))
    }

    func testUnicodeTodoIsTrimmedAndSurvivesRelaunch() {
        let store = makeStore()
        XCTAssertTrue(store.add("  写一段文字 🌱  "))
        XCTAssertEqual(store.notebook.items.first?.text, "写一段文字 🌱")
        XCTAssertEqual(NotebookStore(directory: store.directory).notebook, store.notebook)
    }

    func testCompletionCanBeRestored() {
        let store = makeStore()
        store.add("测试")
        let id = store.notebook.items[0].id
        store.toggle(id)
        XCTAssertTrue(NotebookStore(directory: store.directory).notebook.items[0].completed)
        store.toggle(id)
        XCTAssertFalse(NotebookStore(directory: store.directory).notebook.items[0].completed)
    }

    func testRenameRejectsBlankAndPersists() {
        let store = makeStore()
        store.add("原文")
        let id = store.notebook.items[0].id
        store.rename(id, text: " \n ")
        XCTAssertEqual(store.notebook.items[0].text, "原文")
        store.rename(id, text: " 修改内容 ")
        XCTAssertEqual(NotebookStore(directory: store.directory).notebook.items[0].text, "修改内容")
    }

    func testDeleteOnlyRemovesSelectedItem() {
        let store = makeStore()
        store.add("第一条")
        store.add("第二条")
        store.remove(store.notebook.items[0].id)
        XCTAssertEqual(NotebookStore(directory: store.directory).notebook.items.map(\.text), ["第二条"])
    }

    func testMultilineNoteAndEmptyNotePersist() {
        let store = makeStore()
        store.setNote("第一行\n第二行 ✓\n")
        XCTAssertEqual(NotebookStore(directory: store.directory).notebook.note, "第一行\n第二行 ✓\n")
        store.setNote("")
        XCTAssertEqual(NotebookStore(directory: store.directory).notebook.note, "")
    }

    func testUnknownIDsDoNotAffectExistingItems() {
        let store = makeStore()
        store.add("保留")
        let original = store.notebook
        store.toggle(UUID())
        store.rename(UUID(), text: "无效")
        store.remove(UUID())
        XCTAssertEqual(store.notebook, original)
    }

    func testCorruptPrimaryRecoversBackupAndPreservesOriginal() throws {
        let store = makeStore()
        store.add("已备份")
        let backedUp = store.notebook
        store.setNote("下一次保存")
        try Data("broken data".utf8).write(to: store.file)
        let recovered = NotebookStore(directory: store.directory)
        XCTAssertEqual(recovered.notebook, backedUp)
        XCTAssertNotNil(recovered.errorMessage)
        let preserved = try FileManager.default.contentsOfDirectory(at: store.directory, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("notebook-unreadable-") }
        XCTAssertEqual(preserved.count, 1)
        XCTAssertEqual(try String(contentsOf: preserved[0], encoding: .utf8), "broken data")
        XCTAssertTrue(recovered.add("恢复后可写"))
        XCTAssertEqual(NotebookStore(directory: store.directory).notebook, recovered.notebook)
    }

    func testCorruptDataWithoutBackupCannotBeOverwritten() throws {
        let store = makeStore()
        try Data("original corrupt file".utf8).write(to: store.file)
        let blocked = NotebookStore(directory: store.directory)
        XCTAssertNotNil(blocked.errorMessage)
        XCTAssertFalse(blocked.add("不可保存"))
        blocked.setNote("不可保存")
        XCTAssertEqual(try String(contentsOf: store.file, encoding: .utf8), "original corrupt file")
    }

    func testInaccessibleDirectoryReportsError() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("BlankNoteFile-\(UUID().uuidString)")
        try Data("not a directory".utf8).write(to: file)
        let blocked = NotebookStore(directory: file)
        XCTAssertNotNil(blocked.errorMessage)
        XCTAssertFalse(blocked.add("不可写"))
    }

    func testSaveFailureReportsErrorAndKeepsInMemoryContent() throws {
        let store = makeStore()
        store.add("原内容")
        let preserved = store.directory.appendingPathExtension("preserved")
        try FileManager.default.moveItem(at: store.directory, to: preserved)
        try Data("blocks directory creation".utf8).write(to: store.directory)
        store.setNote("保存失败仍保留在内存")
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(store.notebook.note, "保存失败仍保留在内存")
        XCTAssertEqual(NotebookStore(directory: preserved).notebook.items.first?.text, "原内容")
        XCTAssertTrue(store.hasUnsavedChanges)
        XCTAssertFalse(store.retrySave())
        try FileManager.default.moveItem(at: store.directory, to: store.directory.appendingPathExtension("blocker"))
        try FileManager.default.moveItem(at: preserved, to: store.directory)
        XCTAssertTrue(store.retrySave())
        XCTAssertFalse(store.hasUnsavedChanges)
        XCTAssertEqual(NotebookStore(directory: store.directory).notebook.note, "保存失败仍保留在内存")
    }

    func testUndoCompletionAndRedoPersistWithoutRevertingNote() {
        let store = makeStore()
        store.add("待办")
        let id = store.notebook.items[0].id
        store.toggle(id)
        store.setNote("之后写的笔记")
        store.undo()
        XCTAssertFalse(store.notebook.items[0].completed)
        XCTAssertEqual(store.notebook.note, "之后写的笔记")
        XCTAssertEqual(store.redoTitle, "完成待办")
        store.redo()
        XCTAssertTrue(store.notebook.items[0].completed)
        XCTAssertEqual(NotebookStore(directory: store.directory).notebook, store.notebook)
    }

    func testUndoDeletionRestoresIdentityDateAndPosition() {
        let store = makeStore()
        store.add("一")
        store.add("二")
        store.add("三")
        let original = store.notebook
        store.remove(store.notebook.items[1].id)
        store.undo()
        XCTAssertEqual(store.notebook, original)
        store.redo()
        XCTAssertEqual(store.notebook.items.map(\.text), ["一", "三"])
    }

    func testUndoRenameAndAddWithNoOpKeepingHistory() {
        let store = makeStore()
        store.add("原文")
        let id = store.notebook.items[0].id
        store.rename(id, text: "新文")
        store.rename(id, text: "新文")
        store.remove(UUID())
        store.undo()
        XCTAssertEqual(store.notebook.items[0].text, "原文")
        store.undo()
        XCTAssertTrue(store.notebook.items.isEmpty)
        store.redo()
        XCTAssertEqual(store.notebook.items[0].id, id)
    }

    func testNewActionAfterUndoInvalidatesRedo() {
        let store = makeStore()
        store.add("原文")
        store.rename(store.notebook.items[0].id, text: "修改")
        store.undo()
        store.add("新事项")
        XCTAssertNil(store.redoTitle)
        store.redo()
        XCTAssertEqual(store.notebook.items.map(\.text), ["原文", "新事项"])
    }

    func testReorderingPreservesCompletedItemsAndCanUndo() {
        let store = makeStore()
        for title in ["一", "完成", "二", "三"] { store.add(title) }
        store.toggle(store.notebook.items[1].id)
        let original = store.notebook
        let last = store.notebook.items[3].id
        store.move(last, before: store.notebook.items[0].id)
        XCTAssertEqual(store.notebook.items.map(\.text), ["三", "完成", "一", "二"])
        XCTAssertEqual(store.notebook.items[1], original.items[1])
        XCTAssertEqual(NotebookStore(directory: store.directory).notebook, store.notebook)
        store.undo()
        XCTAssertEqual(store.notebook, original)
        store.redo()
        XCTAssertEqual(store.notebook.items.map(\.text), ["三", "完成", "一", "二"])
        store.move(last, before: nil)
        XCTAssertEqual(store.notebook, original)
    }

    func testInvalidReorderDoesNotAffectDataOrUndoHistory() {
        let store = makeStore()
        store.add("一")
        store.add("完成")
        store.toggle(store.notebook.items[1].id)
        let original = store.notebook
        let undoTitle = store.undoTitle
        store.move(store.notebook.items[0].id, before: store.notebook.items[1].id)
        store.move(store.notebook.items[0].id, before: UUID())
        store.move(UUID(), before: nil)
        XCTAssertEqual(store.notebook, original)
        XCTAssertEqual(store.undoTitle, undoTitle)
    }

    func testLegacyFileLoadsWithoutAnyRewrite() throws {
        let store = makeStore()
        let legacy = Data("""
        {"items":[{"id":"23456789-1234-4567-8912-123456789012","text":"旧版本记录","completed":true,"createdAt":813467859.5}],"note":"旧版本笔记\\n完整保留"}
        """.utf8)
        try legacy.write(to: store.file)
        let upgraded = NotebookStore(directory: store.directory)
        XCTAssertEqual(upgraded.notebook.items[0].text, "旧版本记录")
        XCTAssertTrue(upgraded.notebook.items[0].completed)
        XCTAssertEqual(upgraded.notebook.items[0].createdAt.timeIntervalSinceReferenceDate, 813467859.5)
        XCTAssertEqual(upgraded.notebook.note, "旧版本笔记\n完整保留")
        XCTAssertEqual(try Data(contentsOf: store.file), legacy)
        XCTAssertNil(upgraded.undoTitle)
        XCTAssertFalse(upgraded.hasUnsavedChanges)
    }

    func testUndoHistoryIsBoundedAndDoesNotPersistAcrossRelaunch() {
        let store = makeStore()
        for index in 0..<55 { store.add("\(index)") }
        for _ in 0..<55 { store.undo() }
        XCTAssertEqual(store.notebook.items.count, 5)
        let relaunched = NotebookStore(directory: store.directory)
        XCTAssertEqual(relaunched.notebook, store.notebook)
        XCTAssertNil(relaunched.undoTitle)
        XCTAssertNil(relaunched.redoTitle)
    }
}
