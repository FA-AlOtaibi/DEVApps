import Foundation
import Security

struct AIBoardPayload: Codable {
    let title: String
    let recommendedLayout: String
    let nodes: [AIBoardNode]

    enum CodingKeys: String, CodingKey {
        case title
        case recommendedLayout = "recommended_layout"
        case nodes
    }
}

struct AIBoardNode: Codable {
    let title: String
    let detail: String
}

enum JalaaKeychain {
    private static let service = "com.jalaa.ai"
    private static let account = "openai-api-key"

    static func save(_ value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(insert as CFDictionary, nil)
    }

    static func load() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { return "" }
        return value
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum JalaaAIService {
    static func respond(prompt: String, model: String = "gpt-5.6-luna") async throws -> String {
        let key = JalaaKeychain.load().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw AIError.missingKey }
        guard let url = URL(string: "https://api.openai.com/v1/responses") else { throw AIError.badResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 75

        let body: [String: Any] = [
            "model": model,
            "input": prompt
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            throw AIError.server("OpenAI HTTP \(http.statusCode): \(raw.prefix(240))")
        }

        let object = try JSONSerialization.jsonObject(with: data)
        guard let dict = object as? [String: Any], let output = dict["output"] as? [[String: Any]] else { throw AIError.badResponse }
        for item in output {
            guard let content = item["content"] as? [[String: Any]] else { continue }
            for part in content {
                if let text = part["text"] as? String, !text.isEmpty { return text }
            }
        }
        throw AIError.badResponse
    }

    static func analyzeBoard(source: String, model: String = "gpt-5.6-luna") async throws -> AIBoardPayload {
        let trimmed = String(source.prefix(24_000))
        let prompt = """
        أنت محرك جلاء التعليمي. حلّل النص التالي بالعربية وارجع JSON فقط بدون markdown.
        المطلوب:
        - title: عنوان واضح قصير
        - recommended_layout: واحدة فقط من: map, cards, timeline, comparison, flow
        - nodes: من 5 إلى 7 عناصر، كل عنصر فيه title قصير و detail واضح ومفيد وليس تكراراً حرفياً.
        اختر timeline فقط إذا كان النص فيه تسلسل زمني/مراحل واضحة، comparison فقط إذا توجد مقارنة حقيقية، flow إذا توجد خطوات/سبب ونتيجة، map للمفاهيم المترابطة، وإلا cards.
        لا تخترع معلومات غير موجودة في النص.

        النص:
        \(trimmed)
        """
        let text = try await respond(prompt: prompt, model: model)
        guard let json = extractJSONObject(from: text).data(using: .utf8) else { throw AIError.invalidJSON }
        return try JSONDecoder().decode(AIBoardPayload.self, from: json)
    }

    static func nodeAction(_ kind: String, node: BoardNodeData, source: String, question: String? = nil, model: String = "gpt-5.6-luna") async throws -> String {
        let sourcePart = String(source.prefix(18_000))
        let task: String
        switch kind {
        case "explain": task = "اشرح النقطة بأسلوب مبسط جداً في 3-5 أسطر، مع الحفاظ على الدقة."
        case "deepen": task = "تعمق في النقطة واربطها بمفهومين آخرين من المصدر، واشرح العلاقة باختصار."
        case "example": task = "اعط مثالاً واقعياً قصيراً يوضح النقطة، ولا تضف حقائق غير لازمة."
        case "ask": task = "أجب عن سؤال المستخدم اعتماداً على المصدر فقط. إذا لم تكفِ المعلومات، قل بوضوح إن المصدر لا يكفي. السؤال: \(question ?? "")"
        default: task = "اشرح النقطة."
        }
        let prompt = """
        أنت مساعد جلاء الدراسي. \(task)
        عنوان النقطة: \(node.title)
        تفاصيل النقطة: \(node.detail)
        المصدر الكامل:
        \(sourcePart)
        أجب بالعربية مباشرة وباختصار مفيد.
        """
        return try await respond(prompt: prompt, model: model)
    }

    static func test(model: String = "gpt-5.6-luna") async throws -> Bool {
        let text = try await respond(prompt: "أجب بكلمة واحدة فقط: جاهز", model: model)
        return !text.isEmpty
    }

    private static func extractJSONObject(from text: String) -> String {
        guard let first = text.firstIndex(of: "{"), let last = text.lastIndex(of: "}") else { return text }
        return String(text[first...last])
    }

    enum AIError: LocalizedError {
        case missingKey, badResponse, invalidJSON, server(String)
        var errorDescription: String? {
            switch self {
            case .missingKey: return "أضف OpenAI API Key من قسم ذكاء جلاء في الإعدادات."
            case .badResponse: return "وصل رد غير مفهوم من خدمة الذكاء الاصطناعي."
            case .invalidJSON: return "تعذر تحويل تحليل الذكاء الاصطناعي إلى لوحة. حاول مرة أخرى."
            case .server(let message): return message
            }
        }
    }
}
