import Foundation
import FoundationModels

@Generable
struct ExecutionOrder {
    @Guide(description: "タスク番号を実行すべき順に並べた配列")
    var order: [Int]
}

@MainActor
enum Sorter {
    private static let exemplarsKey = "exemplars.v1"

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    // 実行順に並べ替えたIDリストを返す。失敗時はnil（呼び出し側は何もしない）
    static func sortedOrder(of todos: [Todo]) async -> [UUID]? {
        var prompt = ""
        let exemplars = loadExemplars()
        if !exemplars.isEmpty {
            prompt += "この人が過去に選んだ実行順序の例:\n"
            for exemplar in exemplars.suffix(5) {
                prompt += "- " + exemplar.joined(separator: " → ") + "\n"
            }
            prompt += "\n"
        }
        prompt += "次のタスクを実行すべき順に並べ、番号の配列で答えて:\n"
        for (i, todo) in todos.enumerated() {
            prompt += "\(i): \(todo.text)\n"
        }

        let session = LanguageModelSession(instructions: """
            あなたはタスクの実行順序を決めるアシスタント。
            「過去に選んだ実行順序の例」が与えられた場合は、その人の傾向（どの種類のタスクを先にやり、どれを後回しにするか）を最優先で再現する。
            例がない部分は、朝から夜への自然な流れ、外出する用事のまとめ、タスク間の依存関係、所要時間で補う。
            """)
        guard let response = try? await session.respond(
            to: prompt,
            generating: ExecutionOrder.self,
            options: GenerationOptions(sampling: .greedy)  // 同一入力に同一順序（揺らぎ排除）
        ) else {
            return nil
        }

        var seen = Set<Int>()
        var order = response.content.order.filter { todos.indices.contains($0) && seen.insert($0).inserted }
        order += todos.indices.filter { !seen.contains($0) }
        return Ranker.refine(order.map { todos[$0] }).map(\.id)
    }

    // ✨後の手直し結果を「お手本」として保存（最新10件、同一観測期間内は上書き）
    static func saveExemplar(_ texts: [String], replacingLast: Bool) {
        var exemplars = loadExemplars()
        if replacingLast, !exemplars.isEmpty {
            exemplars.removeLast()
        }
        exemplars.append(texts)
        if exemplars.count > 10 {
            exemplars.removeFirst(exemplars.count - 10)
        }
        UserDefaults.standard.set(try? JSONEncoder().encode(exemplars), forKey: exemplarsKey)
        let snapshot = exemplars
        Task { Ranker.retrain(on: snapshot) }  // ドロップ操作を妨げないよう次のrunloopで
    }

    private static func loadExemplars() -> [[String]] {
        UserDefaults.standard.data(forKey: exemplarsKey)
            .flatMap { try? JSONDecoder().decode([[String]].self, from: $0) } ?? []
    }
}
