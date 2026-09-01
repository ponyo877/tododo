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
        if text.isEmpty {
            todos.remove(at: i)
        } else {
            todos[i].text = text
        }
        save()
    }

    func delete(_ id: UUID) {
        todos.removeAll { $0.id == id }
        save()
    }

    func drop(_ id: UUID, into bucket: Bucket, at offset: Int) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        var offset = offset
        if todos[i].bucket == bucket,
           let current = items(in: bucket).firstIndex(where: { $0.id == id }),
           current < offset {
            offset -= 1
        }
        var todo = todos.remove(at: i)
        todo.bucket = bucket
        let group = items(in: bucket)
        let at = offset < group.count
            ? todos.firstIndex { $0.id == group[offset].id }!
            : todos.lastIndex { $0.bucket == bucket }.map { $0 + 1 } ?? todos.endIndex
        todos.insert(todo, at: at)
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
