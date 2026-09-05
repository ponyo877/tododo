import Foundation
import Observation

enum Bucket: String, Codable, CaseIterable {
    case today, tomorrow, someday

    var label: String {
        switch self {
        case .today: "今日"
        case .tomorrow: "明日"
        case .someday: "いつか"
        }
    }
}

struct Todo: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var bucket: Bucket
    var done = false
}

// 見出しとタスクを1列に並べた表示行。ドラッグで見出しを跨ぐとタスクの区分が変わる
enum Row: Identifiable {
    case header(Bucket)
    case todo(Todo)

    var id: String {
        switch self {
        case .header(let bucket): "header.\(bucket.rawValue)"
        case .todo(let todo): todo.id.uuidString
        }
    }
}

@MainActor @Observable
final class Store {
    var todos: [Todo]

    private static let todosKey = "todos.v1"
    private static let dayKey = "lastOpenedDay"

    init() {
        let data = UserDefaults.standard.data(forKey: Self.todosKey)
        todos = data.flatMap { try? JSONDecoder().decode([Todo].self, from: $0) } ?? []
        rolloverIfNeeded()
    }

    func items(in bucket: Bucket) -> [Todo] {
        todos.filter { $0.bucket == bucket }
    }

    var rows: [Row] {
        Bucket.allCases.flatMap { bucket in [Row.header(bucket)] + items(in: bucket).map(Row.todo) }
    }

    func add(_ text: String, to bucket: Bucket) {
        todos.insert(Todo(text: text, bucket: bucket), at: insertionIndex(in: bucket, done: false))
        save()
    }

    func toggle(_ id: UUID) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        var todo = todos.remove(at: i)
        todo.done.toggle()
        todos.insert(todo, at: insertionIndex(in: todo.bucket, done: todo.done))
        save()
    }

    func rename(_ id: UUID, to text: String) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[i].text = text
        save()
    }

    func delete(_ id: UUID) {
        todos.removeAll { $0.id == id }
        save()
    }

    // 表示行の並べ替え。移動後の位置から区分を決め直す（直前の見出しがその行の区分）
    func move(from source: IndexSet, to destination: Int) {
        var rows = rows
        rows.move(fromOffsets: source, toOffset: destination)
        var bucket = Bucket.today
        var moved: [Todo] = []
        for row in rows {
            switch row {
            case .header(let b):
                bucket = b
            case .todo(var todo):
                todo.bucket = bucket
                moved.append(todo)
            }
        }
        todos = moved
        save()
    }

    // 区分内の未完了タスクを指定IDの順に並べ替える（完了行は動かさない）
    func reorder(_ bucket: Bucket, to orderedIDs: [UUID]) {
        let slots = todos.indices.filter { todos[$0].bucket == bucket && !todos[$0].done }
        let byID = Dictionary(uniqueKeysWithValues: slots.map { (todos[$0].id, todos[$0]) })
        let ordered = orderedIDs.compactMap { byID[$0] }
        guard ordered.count == slots.count else { return }
        for (slot, todo) in zip(slots, ordered) {
            todos[slot] = todo
        }
        save()
    }

    func rolloverIfNeeded() {
        let today = Calendar.current.startOfDay(for: .now)
        if let last = UserDefaults.standard.object(forKey: Self.dayKey) as? Date,
           Calendar.current.isDate(last, inSameDayAs: today) {
            return
        }
        todos.removeAll { $0.done }
        var moved = todos.filter { $0.bucket == .tomorrow }
        todos.removeAll { $0.bucket == .tomorrow }
        for i in moved.indices {
            moved[i].bucket = .today
        }
        todos.insert(contentsOf: moved, at: insertionIndex(in: .today, done: false))
        UserDefaults.standard.set(today, forKey: Self.dayKey)
        save()
    }

    // 表示順のルール: 各区分内で未完了が上、完了が下。挿入位置はそれに従う
    private func insertionIndex(in bucket: Bucket, done: Bool) -> Int {
        if done {
            return todos.lastIndex { $0.bucket == bucket }.map { $0 + 1 } ?? todos.endIndex
        }
        return todos.lastIndex { $0.bucket == bucket && !$0.done }.map { $0 + 1 }
            ?? todos.firstIndex { $0.bucket == bucket }
            ?? todos.endIndex
    }

    private func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(todos), forKey: Self.todosKey)
    }
}
