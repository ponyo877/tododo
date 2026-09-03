import Foundation
import NaturalLanguage

// 手直し履歴から実行順の好みを学ぶ線形ランカー（ペアワイズロジスティック + SGD）。
// LLMの並びを土台に、学習が自信を持つペアだけを矯正する。
@MainActor
enum Ranker {
    private static let weightsKey = "ranker.v1"
    private static let minPairs = 30    // 教師ペアがこれ未満の間は沈黙する
    private static let margin = 1.0     // スコア差がこれを超えたペアだけLLM順を上書き

    private static let embedder: NLContextualEmbedding? = {
        guard let e = NLContextualEmbedding(language: .japanese) else { return nil }
        guard e.hasAvailableAssets else {
            e.requestAssets { _, _ in }  // 次回以降に備えて取得だけ仕掛ける
            return nil
        }
        return (try? e.load()) != nil ? e : nil
    }()

    private static var cache: [String: [Double]] = [:]

    @discardableResult
    static func retrain(on exemplars: [[String]]) -> Int {
        var pairs: [([Double], [Double])] = []
        for exemplar in exemplars {
            for i in exemplar.indices {
                for j in exemplar.indices where j > i {
                    if let a = vector(exemplar[i]), let b = vector(exemplar[j]) {
                        pairs.append((a, b))
                    }
                }
            }
        }
        guard pairs.count >= minPairs, let dim = pairs.first?.0.count else { return pairs.count }
        var w = [Double](repeating: 0, count: dim)
        let rate = 0.1
        for _ in 0..<10 {
            for (a, b) in pairs {
                var d = 0.0
                for k in 0..<dim { d += w[k] * (a[k] - b[k]) }
                let g = rate * (1 - 1 / (1 + exp(-d)))
                for k in 0..<dim { w[k] += g * (a[k] - b[k]) }
            }
        }
        UserDefaults.standard.set(try? JSONEncoder().encode(w), forKey: weightsKey)
        return pairs.count
    }

    // LLMの並びを土台に、自信のある隣接ペアだけ入れ替える（バブル方式・それ以外は維持）
    static func refine(_ todos: [Todo]) -> [Todo] {
        guard let data = UserDefaults.standard.data(forKey: weightsKey),
              let w = try? JSONDecoder().decode([Double].self, from: data) else { return todos }
        var scores: [UUID: Double] = [:]
        for todo in todos {
            if let v = vector(todo.text), v.count == w.count {
                scores[todo.id] = zip(w, v).reduce(0) { $0 + $1.0 * $1.1 }
            }
        }
        var order = todos
        for _ in order.indices {
            var swapped = false
            for i in 0..<(order.count - 1) {
                guard let a = scores[order[i].id], let b = scores[order[i + 1].id] else { continue }
                if b - a > margin {
                    order.swapAt(i, i + 1)
                    swapped = true
                }
            }
            if !swapped { break }
        }
        return order
    }

    static func score(_ text: String) -> Double? {
        guard let data = UserDefaults.standard.data(forKey: weightsKey),
              let w = try? JSONDecoder().decode([Double].self, from: data),
              let v = vector(text), v.count == w.count else { return nil }
        return zip(w, v).reduce(0) { $0 + $1.0 * $1.1 }
    }

    // 文の平均トークンベクトル（L2正規化）。結果はキャッシュする
    private static func vector(_ text: String) -> [Double]? {
        if let v = cache[text] { return v }
        guard let embedder,
              let result = try? embedder.embeddingResult(for: text, language: .japanese) else { return nil }
        var sum = [Double](repeating: 0, count: embedder.dimension)
        result.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { vector, _ in
            for k in vector.indices { sum[k] += vector[k] }
            return true
        }
        let norm = sqrt(sum.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return nil }
        let v = sum.map { $0 / norm }
        cache[text] = v
        return v
    }
}
