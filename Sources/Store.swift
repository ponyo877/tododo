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

// 事前に定義したタスク群。右スワイプやドラッグで今日へ一括投入する型紙
struct TaskSet: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var items: [String]

    /// 入力欄で編集するときの1行表現（例: 「朝: 白湯, ストレッチ, 日記」）
    var definition: String {
        items.isEmpty ? name : "\(name): \(items.joined(separator: ", "))"
    }

    /// 「名前: 項目, 項目」を分解する。区切りは : ： と , 、
    static func parse(_ line: String) -> (name: String, items: [String]) {
        let parts = line.split(maxSplits: 1, whereSeparator: { $0 == ":" || $0 == "：" })
        let name = parts.first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        let body = parts.count > 1 ? parts[1] : ""
        var seen = Set<String>()
        let items = body.split(whereSeparator: { $0 == "," || $0 == "、" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        return (name.isEmpty ? line.trimmingCharacters(in: .whitespaces) : name, items)
    }
}

// 見出し・タスク・セットを1列に並べた表示行。ドラッグで見出しを跨ぐとタスクの区分が変わる
enum Row: Identifiable {
    case header(Bucket)
    case todo(Todo)
    case setsHeader
    case set(TaskSet)

    var id: String {
        switch self {
        case .header(let bucket): "header.\(bucket.rawValue)"
        case .todo(let todo): todo.id.uuidString
        case .setsHeader: "header.sets"
        case .set(let set): set.id.uuidString
        }
    }
}

@MainActor @Observable
final class Store {
    var todos: [Todo]
    var sets: [TaskSet]

    private static let todosKey = "todos.v1"
    private static let setsKey = "sets.v1"
    private static let dayKey = "lastOpenedDay"

    init() {
        let defaults = UserDefaults.standard
        todos = defaults.data(forKey: Self.todosKey).flatMap { try? JSONDecoder().decode([Todo].self, from: $0) } ?? []
        sets = defaults.data(forKey: Self.setsKey).flatMap { try? JSONDecoder().decode([TaskSet].self, from: $0) } ?? []
        rolloverIfNeeded()
    }

    func items(in bucket: Bucket) -> [Todo] {
        todos.filter { $0.bucket == bucket }
    }

    var rows: [Row] {
        Bucket.allCases.flatMap { bucket in [Row.header(bucket)] + items(in: bucket).map(Row.todo) }
            + [Row.setsHeader] + sets.map(Row.set)
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

    func addSet(name: String, items: [String]) {
        sets.append(TaskSet(name: name, items: items))
        save()
    }

    func updateSet(_ id: UUID, name: String, items: [String]) {
        guard let i = sets.firstIndex(where: { $0.id == id }) else { return }
        sets[i].name = name
        sets[i].items = items
        save()
    }

    func deleteSet(_ id: UUID) {
        sets.removeAll { $0.id == id }
        save()
    }

    // セットの項目を区分の未完了末尾へ一括追加。同じ文言の未完了があれば飛ばす
    func inject(_ set: TaskSet, into bucket: Bucket) {
        var pending = Set(items(in: bucket).filter { !$0.done }.map(\.text))
        for text in set.items where pending.insert(text).inserted {
            todos.insert(Todo(text: text, bucket: bucket), at: insertionIndex(in: bucket, done: false))
        }
        save()
    }

    // 表示行の並べ替え。移動後の位置から区分を決め直す（直前の見出しがその行の区分）。
    // セット行を区分へ落としたら「投入」（セット自体は動かさない）。タスクをセット区分へは入れられない
    func move(from source: IndexSet, to destination: Int) {
        var rows = rows
        let moving = source.sorted().reversed().map { rows.remove(at: $0) }.reversed()
        rows.insert(contentsOf: moving, at: destination - source.filter { $0 < destination }.count)
        var bucket: Bucket? = .today  // nil はセット区分
        var movedTodos: [Todo] = []
        var movedSets: [TaskSet] = []
        var dropped: (set: TaskSet, bucket: Bucket)?
        for row in rows {
            switch row {
            case .header(let b):
                bucket = b
            case .setsHeader:
                bucket = nil
            case .todo(var todo):
                guard let b = bucket else {
                    todos = todos  // 無効な移動。再代入して表示を元に戻す
                    return
                }
                todo.bucket = b
                movedTodos.append(todo)
            case .set(let set):
                if let b = bucket {
                    dropped = (set, b)
                } else {
                    movedSets.append(set)
                }
            }
        }
        if let dropped {
            todos = todos
            inject(dropped.set, into: dropped.bucket)
            return
        }
        todos = movedTodos
        sets = movedSets
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
        UserDefaults.standard.set(try? JSONEncoder().encode(sets), forKey: Self.setsKey)
    }
}
