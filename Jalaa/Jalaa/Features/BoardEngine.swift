import Foundation

struct BoardNodeData: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let detail: String

    init(id: UUID = UUID(), title: String, detail: String) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}

enum BoardEngine {
    static func nodes(from source: String) -> [BoardNodeData] {
        let cleaned = source
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return [] }

        let separators = CharacterSet(charactersIn: ".!?؟؛\n")
        var sentences = cleaned
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 12 }

        if sentences.isEmpty { sentences = [cleaned] }

        return Array(sentences.prefix(7)).enumerated().map { index, sentence in
            let words = sentence.split(separator: " ")
            let titleWords = words.prefix(min(6, words.count))
            let title = titleWords.joined(separator: " ") + (words.count > 6 ? "…" : "")
            return BoardNodeData(title: title.isEmpty ? "نقطة \(index + 1)" : title, detail: sentence)
        }
    }

    static func suggestedTitle(from source: String, fallback: String = "لوحة جديدة") -> String {
        guard let first = nodes(from: source).first else { return fallback }
        let title = first.title.replacingOccurrences(of: "…", with: "")
        return title.count > 38 ? String(title.prefix(38)) + "…" : title
    }

    static func encode(_ nodes: [BoardNodeData]) -> String {
        guard let data = try? JSONEncoder().encode(nodes) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func decode(_ json: String) -> [BoardNodeData] {
        guard !json.isEmpty, let data = json.data(using: .utf8), let nodes = try? JSONDecoder().decode([BoardNodeData].self, from: data) else { return [] }
        return nodes
    }

    static func fromAI(_ payload: AIBoardPayload) -> [BoardNodeData] {
        payload.nodes.prefix(7).map { BoardNodeData(title: $0.title, detail: $0.detail) }
    }

    static func layoutIndex(for key: String) -> Int {
        switch key.lowercased() {
        case "map": return 1
        case "cards": return 2
        case "timeline": return 3
        case "comparison": return 4
        case "flow": return 5
        default: return 2
        }
    }

    static func explain(_ node: BoardNodeData) -> String { "ببساطة: \(node.detail)" }

    static func deepen(_ node: BoardNodeData, source: String) -> String {
        let related = nodes(from: source).filter { $0.detail != node.detail }.prefix(2).map(\.detail)
        if related.isEmpty { return "هذه هي الفكرة الأساسية في المصدر: \(node.detail)" }
        return "الفكرة الأساسية:\n\(node.detail)\n\nوترتبط كذلك بـ:\n• " + related.joined(separator: "\n• ")
    }

    static func example(_ node: BoardNodeData) -> String {
        "مثال تطبيقي: تخيّل موقفًا واقعيًا تنطبق فيه الفكرة التالية: «\(node.detail)»."
    }

    static func answer(question: String, node: BoardNodeData, source: String) -> String {
        let qWords = Set(question.split(separator: " ").map { String($0).lowercased() }.filter { $0.count > 2 })
        let ranked = nodes(from: source).map { item -> (BoardNodeData, Int) in
            let text = (item.title + " " + item.detail).lowercased()
            let score = qWords.reduce(0) { $0 + (text.contains($1) ? 1 : 0) }
            return (item, score)
        }.sorted { $0.1 > $1.1 }
        if let best = ranked.first, best.1 > 0 { return best.0.detail }
        return node.detail
    }
}
