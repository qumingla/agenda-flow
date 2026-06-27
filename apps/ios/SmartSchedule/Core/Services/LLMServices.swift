import Foundation
import Security

enum LLMProviderPreset: String, CaseIterable, Identifiable, Sendable {
    case local
    case openAI
    case deepSeek
    case qwen
    case moonshot
    case zhipu
    case openRouter
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .local: "本地规则"
        case .openAI: "OpenAI"
        case .deepSeek: "DeepSeek"
        case .qwen: "通义千问"
        case .moonshot: "Kimi / Moonshot"
        case .zhipu: "智谱 GLM"
        case .openRouter: "OpenRouter"
        case .custom: "自定义兼容接口"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .local: ""
        case .openAI: "https://api.openai.com/v1"
        case .deepSeek: "https://api.deepseek.com"
        case .qwen: "https://dashscope.aliyuncs.com/compatible-mode/v1"
        case .moonshot: "https://api.moonshot.cn/v1"
        case .zhipu: "https://open.bigmodel.cn/api/paas/v4"
        case .openRouter: "https://openrouter.ai/api/v1"
        case .custom: ""
        }
    }

    var defaultModel: String {
        switch self {
        case .local: "MockLLMService"
        case .openAI: "gpt-4.1-mini"
        case .deepSeek: "deepseek-chat"
        case .qwen: "qwen-plus"
        case .moonshot: "moonshot-v1-8k"
        case .zhipu: "glm-4-flash"
        case .openRouter: "openai/gpt-4.1-mini"
        case .custom: ""
        }
    }

    var helpText: String {
        switch self {
        case .local:
            "完全离线，不上传输入内容，识别能力有限。"
        case .custom:
            "填写第三方 OpenAI-compatible Base URL，例如以 /v1 结尾的接口根地址。"
        default:
            "使用该厂商的 OpenAI-compatible Chat Completions 接口。Base URL 和模型名可手动调整。"
        }
    }
}

struct LLMRuntimeConfiguration: Sendable {
    var provider: LLMProviderPreset
    var baseURL: URL
    var modelName: String
    var apiKey: String
    var useJSONMode: Bool
    var saveRawResponse: Bool
    var timeoutSeconds: Double
}

struct LLMRemoteModel: Identifiable, Hashable, Sendable {
    var id: String
    var ownedBy: String?
}

enum LLMPreferencesKey {
    static let provider = "llmProviderPreset"
    static let baseURL = "llmBaseURL"
    static let modelName = "llmModelName"
    static let useJSONMode = "llmUseJSONMode"
    static let saveRawResponse = "llmSaveRawResponse"
    static let timeoutSeconds = "llmTimeoutSeconds"
    static let fallbackToMock = "llmFallbackToMock"
    static let fetchedModels = "llmFetchedModels"
    static let cloudEnabled = "cloudLLMEnabled"
    static let privacyLocalOnly = "privacyLocalOnly"
}

enum LLMKeychainStore {
    private static var service: String {
        "\(Bundle.main.bundleIdentifier ?? "local.smartschedule.beta").llm"
    }

    static func account(for provider: LLMProviderPreset) -> String {
        "api-key.\(provider.rawValue)"
    }

    static func readAPIKey(for provider: LLMProviderPreset) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: provider),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return ""
        }
        guard status == errSecSuccess else {
            throw BetaAppError.keychainFailed(errorMessage(for: status))
        }
        guard let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return ""
        }
        return key
    }

    static func saveAPIKey(_ apiKey: String, for provider: LLMProviderPreset) throws {
        let account = account(for: provider)
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try deleteAPIKey(for: provider)
            return
        }

        let data = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw BetaAppError.keychainFailed(errorMessage(for: updateStatus))
        }

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw BetaAppError.keychainFailed(errorMessage(for: addStatus))
        }
    }

    static func deleteAPIKey(for provider: LLMProviderPreset) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: provider)
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw BetaAppError.keychainFailed(errorMessage(for: status))
        }
    }

    private static func errorMessage(for status: OSStatus) -> String {
        SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
    }
}

@MainActor
enum LLMServiceFactory {
    static func makeService() throws -> any LLMService {
        let defaults = UserDefaults.standard
        let provider = provider(from: defaults)
        let localOnly = bool(for: LLMPreferencesKey.privacyLocalOnly, default: true, defaults: defaults)
        let cloudEnabled = bool(for: LLMPreferencesKey.cloudEnabled, default: false, defaults: defaults)

        guard cloudEnabled, !localOnly, provider != .local else {
            return MockLLMService()
        }

        let cloudService = try makeConfiguredCloudService()
        let shouldFallback = bool(for: LLMPreferencesKey.fallbackToMock, default: true, defaults: defaults)
        if shouldFallback {
            return FallbackLLMService(primary: cloudService, fallback: MockLLMService())
        }
        return cloudService
    }

    static func makeConfiguredCloudService() throws -> any LLMService {
        OpenAICompatibleLLMService(configuration: try makeRuntimeConfiguration())
    }

    static func makeRuntimeConfiguration() throws -> LLMRuntimeConfiguration {
        let defaults = UserDefaults.standard
        let provider = provider(from: defaults)
        guard provider != .local else {
            throw BetaAppError.invalidLLMConfiguration("请选择一个云端 Provider。")
        }

        let baseURLString = string(
            for: LLMPreferencesKey.baseURL,
            default: provider.defaultBaseURL,
            defaults: defaults
        )
        let modelName = string(
            for: LLMPreferencesKey.modelName,
            default: provider.defaultModel,
            defaults: defaults
        )
        let apiKey = try LLMKeychainStore.readAPIKey(for: provider)

        guard !baseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BetaAppError.invalidLLMConfiguration("Base URL 不能为空。")
        }
        guard let baseURL = URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)),
              baseURL.scheme != nil,
              baseURL.host != nil else {
            throw BetaAppError.invalidLLMConfiguration("Base URL 不是有效 URL。")
        }
        guard !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BetaAppError.invalidLLMConfiguration("模型名不能为空。")
        }
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BetaAppError.invalidLLMConfiguration("请先保存 \(provider.displayName) 的 API Key。")
        }

        let timeout = defaults.double(forKey: LLMPreferencesKey.timeoutSeconds)
        let configuration = LLMRuntimeConfiguration(
            provider: provider,
            baseURL: baseURL,
            modelName: modelName.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: apiKey,
            useJSONMode: bool(for: LLMPreferencesKey.useJSONMode, default: true, defaults: defaults),
            saveRawResponse: bool(for: LLMPreferencesKey.saveRawResponse, default: false, defaults: defaults),
            timeoutSeconds: timeout > 0 ? min(max(timeout, 15), 180) : 60
        )
        return configuration
    }

    static func fetchAvailableModels() async throws -> [LLMRemoteModel] {
        let configuration = try makeRuntimeConfiguration()
        return try await OpenAICompatibleLLMService(configuration: configuration).fetchModels()
    }

    static func provider(from defaults: UserDefaults = .standard) -> LLMProviderPreset {
        let rawValue = defaults.string(forKey: LLMPreferencesKey.provider) ?? LLMProviderPreset.local.rawValue
        return LLMProviderPreset(rawValue: rawValue) ?? .local
    }

    static func bool(for key: String, default defaultValue: Bool, defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }
        return defaults.bool(forKey: key)
    }

    static func string(for key: String, default defaultValue: String, defaults: UserDefaults = .standard) -> String {
        let value = defaults.string(forKey: key) ?? ""
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultValue : trimmed
    }
}

@MainActor
private struct FallbackLLMService: LLMService {
    var primary: any LLMService
    var fallback: MockLLMService

    func extractCandidates(from text: String, referenceDate: Date) async throws -> LLMExtractionResult {
        do {
            return try await primary.extractCandidates(from: text, referenceDate: referenceDate)
        } catch {
            let fallbackResult = try await fallback.extractCandidates(from: text, referenceDate: referenceDate)
            return LLMExtractionResult(
                drafts: fallbackResult.drafts,
                promptVersion: fallbackResult.promptVersion,
                modelProvider: "local-fallback",
                modelName: fallbackResult.modelName,
                rawResponse: "Cloud LLM failed and local fallback was used: \(error.localizedDescription)",
                parsedResponse: fallbackResult.parsedResponse,
                tokenUsage: fallbackResult.tokenUsage,
                costEstimate: fallbackResult.costEstimate
            )
        }
    }
}

@MainActor
struct OpenAICompatibleLLMService: LLMService {
    var configuration: LLMRuntimeConfiguration

    func fetchModels() async throws -> [LLMRemoteModel] {
        var request = URLRequest(url: try modelsURL())
        request.httpMethod = "GET"
        request.timeoutInterval = configuration.timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw BetaAppError.llmRequestFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BetaAppError.llmRequestFailed("没有收到 HTTP 响应。")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw BetaAppError.llmRequestFailed(errorBody(from: data, statusCode: httpResponse.statusCode))
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let responseBody: OpenAIModelsResponse
        do {
            responseBody = try decoder.decode(OpenAIModelsResponse.self, from: data)
        } catch {
            throw BetaAppError.invalidLLMResponse("Models 响应不是 OpenAI-compatible JSON：\(error.localizedDescription)")
        }

        let models = responseBody.data
            .map { LLMRemoteModel(id: $0.id, ownedBy: $0.ownedBy) }
            .filter { !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }

        guard !models.isEmpty else {
            throw BetaAppError.invalidLLMResponse("没有获取到可用模型。")
        }
        return models
    }

    func extractCandidates(from text: String, referenceDate: Date) async throws -> LLMExtractionResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BetaAppError.emptyInput
        }

        do {
            return try await requestExtraction(from: trimmed, referenceDate: referenceDate, useJSONMode: configuration.useJSONMode)
        } catch {
            if configuration.useJSONMode, shouldRetryWithoutJSONMode(after: error) {
                return try await requestExtraction(from: trimmed, referenceDate: referenceDate, useJSONMode: false)
            }
            throw error
        }
    }

    private func requestExtraction(from text: String, referenceDate: Date, useJSONMode: Bool) async throws -> LLMExtractionResult {
        let prompt = extractionPrompt(for: text, referenceDate: referenceDate)
        let requestData = try requestBody(prompt: prompt, useJSONMode: useJSONMode)
        var request = URLRequest(url: try chatCompletionsURL())
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = requestData

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw BetaAppError.llmRequestFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BetaAppError.llmRequestFailed("没有收到 HTTP 响应。")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw BetaAppError.llmRequestFailed(errorBody(from: data, statusCode: httpResponse.statusCode))
        }

        let chatResponse: OpenAIChatResponse
        do {
            chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        } catch {
            throw BetaAppError.invalidLLMResponse("Chat Completions 响应不是预期 JSON：\(error.localizedDescription)")
        }

        guard let content = chatResponse.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw BetaAppError.invalidLLMResponse("choices[0].message.content 为空。")
        }

        let jsonText = try extractJSONObject(from: content)
        let drafts = try decodeDrafts(from: jsonText, referenceDate: referenceDate)
        let tokenUsage = chatResponse.usage?.jsonString ?? "{}"
        let rawResponse = configuration.saveRawResponse
            ? content
            : "Raw cloud response hidden. response_sha256=\(BetaHash.sha256(content))"

        return LLMExtractionResult(
            drafts: drafts,
            promptVersion: "openai-compatible-extraction-v1",
            modelProvider: configuration.provider.rawValue,
            modelName: configuration.modelName,
            rawResponse: rawResponse,
            parsedResponse: drafts.map(\.title).joined(separator: ", "),
            tokenUsage: tokenUsage
        )
    }

    private func requestBody(prompt: String, useJSONMode: Bool) throws -> Data {
        var body: [String: Any] = [
            "model": configuration.modelName,
            "temperature": 0.1,
            "messages": [
                [
                    "role": "system",
                    "content": "You are AgendaFlow's strict calendar extraction engine. Return only valid JSON."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        if useJSONMode {
            body["response_format"] = ["type": "json_object"]
        }

        return try JSONSerialization.data(withJSONObject: body, options: [])
    }

    private func chatCompletionsURL() throws -> URL {
        let base = configuration.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString = base.hasSuffix("/chat/completions") ? base : "\(base)/chat/completions"
        guard let url = URL(string: urlString) else {
            throw BetaAppError.invalidLLMConfiguration("无法拼接 Chat Completions URL。")
        }
        return url
    }

    private func modelsURL() throws -> URL {
        let base = configuration.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString = base.hasSuffix("/models") ? base : "\(base)/models"
        guard let url = URL(string: urlString) else {
            throw BetaAppError.invalidLLMConfiguration("无法拼接 Models URL。")
        }
        return url
    }

    private func extractionPrompt(for text: String, referenceDate: Date) -> String {
        let referenceISO = makeAgendaFlowISO8601Formatter(fractionalSeconds: true).string(from: referenceDate)
        let timezone = TimeZone.current.identifier
        return """
        请从用户输入中提取候选日程。不要编造原文没有支持的时间、地点、人物或材料。

        解析相对时间时必须使用：
        - reference_date: \(referenceISO)
        - timezone: \(timezone)

        只返回一个 JSON object，结构如下：
        {
          "schema_version": "1.0",
          "items": [
            {
              "title": {"value": "日程标题", "confidence": 0.0, "source_text": "原文依据"},
              "time": {
                "start": "ISO-8601 或 null",
                "end": "ISO-8601 或 null",
                "timezone": "\(timezone)",
                "is_all_day": false,
                "status": "confirmed | inferred | missing | needs_confirmation",
                "confidence": 0.0,
                "source_text": "原文依据"
              },
              "location": {
                "type": "physical | online | phone | tbd | not_applicable",
                "name": "",
                "address": "",
                "status": "confirmed | inferred | missing | needs_confirmation",
                "confidence": 0.0,
                "source_text": "原文依据"
              },
              "urgency": {"level": "low | medium | high | critical | unknown", "reason": "", "confidence": 0.0},
              "notes": "",
              "source_summary": "",
              "questions_for_user": [],
              "overall_confidence": 0.0,
              "dynamic_fields": [
                {
                  "key": "materials_to_bring",
                  "label": "需携带材料",
                  "type": "string | number | boolean | datetime | url | person | location | enum | file",
                  "value": "",
                  "confidence": 0.0,
                  "source_text": "原文依据"
                }
              ]
            }
          ]
        }

        规则：
        1. 一条输入可以返回 0、1 或多个 items。
        2. 无明确时间时 start/end 必须为 null，status 用 missing 或 needs_confirmation。
        3. 无明确地点时 type 用 tbd 或 not_applicable，不要填假地址。
        4. 每个关键字段必须保留 source_text；没有依据时 source_text 为空。
        5. confidence 必须是 0 到 1 之间的小数。

        用户输入：
        \(text)
        """
    }

    private func decodeDrafts(from jsonText: String, referenceDate: Date) throws -> [CandidateDraft] {
        guard let data = jsonText.data(using: .utf8) else {
            throw BetaAppError.invalidLLMResponse("JSON 文本无法转为 UTF-8。")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let envelope: LLMExtractionEnvelope
        do {
            envelope = try decoder.decode(LLMExtractionEnvelope.self, from: data)
        } catch {
            throw BetaAppError.invalidLLMResponse("结构化 JSON 解码失败：\(error.localizedDescription)")
        }

        return envelope.items.map { item in
            let title = item.title?.value.nonEmpty ?? "待确认日程"
            let startDate = parseDate(item.time?.start)
            let endDate = parseDate(item.time?.end) ?? startDate.map {
                Calendar.current.date(byAdding: .minute, value: 60, to: $0) ?? $0
            }
            let locationType = LocationType(llmValue: item.location?.type)
            let locationStatus = TimeFieldStatus(llmValue: item.location?.status, hasValue: !(item.location?.name.nonEmpty ?? "").isEmpty)
            let timeStatus = TimeFieldStatus(llmValue: item.time?.status, hasValue: startDate != nil)
            let dynamicFields = item.dynamicFields.compactMap { field -> CustomFieldDraft? in
                guard let key = field.key.nonEmpty,
                      let label = field.label.nonEmpty,
                      let value = field.value.nonEmpty else {
                    return nil
                }
                return CustomFieldDraft(
                    key: key,
                    label: label,
                    type: CustomFieldType(llmValue: field.type),
                    value: value,
                    confidence: field.confidence.clampedConfidence(default: 0.6),
                    sourceText: field.sourceText ?? ""
                )
            }

            return CandidateDraft(
                title: title,
                titleConfidence: item.title?.confidence.clampedConfidence(default: 0.65) ?? 0.65,
                titleSourceText: item.title?.sourceText ?? "",
                startDate: startDate,
                endDate: endDate,
                timeStatus: timeStatus,
                timeSourceText: item.time?.sourceText ?? "",
                locationType: locationType,
                locationName: item.location?.name ?? "",
                locationAddress: item.location?.address ?? "",
                locationStatus: locationStatus,
                locationSourceText: item.location?.sourceText ?? "",
                priority: PriorityLevel(llmValue: item.urgency?.level),
                urgencyReason: item.urgency?.reason ?? "",
                notes: item.notes ?? "",
                sourceSummary: item.sourceSummary ?? "",
                questions: item.questionsForUser ?? [],
                confidence: item.overallConfidence.clampedConfidence(default: 0.55),
                dynamicFields: dynamicFields
            )
        }
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              value.lowercased() != "null" else {
            return nil
        }
        if let date = makeAgendaFlowISO8601Formatter(fractionalSeconds: true).date(from: value) {
            return date
        }
        if let date = makeAgendaFlowISO8601Formatter(fractionalSeconds: false).date(from: value) {
            return date
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: value)
    }

    private func extractJSONObject(from content: String) throws -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
            return trimmed
        }

        if let fencedStart = trimmed.range(of: "```json"),
           let fencedEnd = trimmed.range(of: "```", range: fencedStart.upperBound..<trimmed.endIndex) {
            return String(trimmed[fencedStart.upperBound..<fencedEnd.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let first = trimmed.firstIndex(of: "{"),
              let last = trimmed.lastIndex(of: "}"),
              first < last else {
            throw BetaAppError.invalidLLMResponse("没有找到 JSON object。")
        }
        return String(trimmed[first...last])
    }

    private func errorBody(from data: Data, statusCode: Int) -> String {
        let body = String(data: data, encoding: .utf8) ?? ""
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "HTTP \(statusCode)" : "HTTP \(statusCode): \(trimmed)"
    }

    private func shouldRetryWithoutJSONMode(after error: Error) -> Bool {
        guard case BetaAppError.llmRequestFailed(let message) = error else {
            return false
        }
        let lowercased = message.lowercased()
        return lowercased.contains("response_format")
            || lowercased.contains("json_object")
            || lowercased.contains("json mode")
    }
}

private struct OpenAIChatResponse: Decodable {
    var choices: [Choice]
    var usage: Usage?

    struct Choice: Decodable {
        var message: Message
    }

    struct Message: Decodable {
        var content: String
    }

    struct Usage: Codable {
        var promptTokens: Int?
        var completionTokens: Int?
        var totalTokens: Int?

        var jsonString: String {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            guard let data = try? encoder.encode(self) else {
                return "{}"
            }
            return String(decoding: data, as: UTF8.self)
        }
    }
}

private struct OpenAIModelsResponse: Decodable {
    var data: [ModelItem]

    struct ModelItem: Decodable {
        var id: String
        var ownedBy: String?
    }
}

private struct LLMExtractionEnvelope: Decodable {
    var items: [LLMExtractionItem]
}

private struct LLMExtractionItem: Decodable {
    var title: LLMTextField?
    var time: LLMTimeField?
    var location: LLMLocationField?
    var urgency: LLMUrgencyField?
    var notes: String?
    var sourceSummary: String?
    var questionsForUser: [String]?
    var overallConfidence: Double?
    var dynamicFields: [LLMDynamicField]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(LLMTextField.self, forKey: .title)
        time = try container.decodeIfPresent(LLMTimeField.self, forKey: .time)
        location = try container.decodeIfPresent(LLMLocationField.self, forKey: .location)
        urgency = try container.decodeIfPresent(LLMUrgencyField.self, forKey: .urgency)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        sourceSummary = try container.decodeIfPresent(String.self, forKey: .sourceSummary)
        questionsForUser = try container.decodeIfPresent([String].self, forKey: .questionsForUser)
        overallConfidence = try container.decodeIfPresent(Double.self, forKey: .overallConfidence)
        dynamicFields = try container.decodeIfPresent([LLMDynamicField].self, forKey: .dynamicFields) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case time
        case location
        case urgency
        case notes
        case sourceSummary
        case questionsForUser
        case overallConfidence
        case dynamicFields
    }
}

private struct LLMTextField: Decodable {
    var value: String?
    var confidence: Double?
    var sourceText: String?
}

private struct LLMTimeField: Decodable {
    var start: String?
    var end: String?
    var timezone: String?
    var isAllDay: Bool?
    var status: String?
    var confidence: Double?
    var sourceText: String?
}

private struct LLMLocationField: Decodable {
    var type: String?
    var name: String?
    var address: String?
    var status: String?
    var confidence: Double?
    var sourceText: String?
}

private struct LLMUrgencyField: Decodable {
    var level: String?
    var reason: String?
    var confidence: Double?
}

private struct LLMDynamicField: Decodable {
    var key: String?
    var label: String?
    var type: String?
    var value: String?
    var confidence: Double?
    var sourceText: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decodeIfPresent(String.self, forKey: .key)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
        sourceText = try container.decodeIfPresent(String.self, forKey: .sourceText)
        value = try Self.decodeValue(from: container)
    }

    private enum CodingKeys: String, CodingKey {
        case key
        case label
        case type
        case value
        case confidence
        case sourceText
    }

    private static func decodeValue(from container: KeyedDecodingContainer<CodingKeys>) throws -> String? {
        if let value = try container.decodeIfPresent(String.self, forKey: .value) {
            return value
        }
        if let value = try container.decodeIfPresent(Int.self, forKey: .value) {
            return String(value)
        }
        if let value = try container.decodeIfPresent(Double.self, forKey: .value) {
            return String(value)
        }
        if let value = try container.decodeIfPresent(Bool.self, forKey: .value) {
            return value ? "true" : "false"
        }
        return nil
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }
}

private extension Optional where Wrapped == Double {
    func clampedConfidence(default defaultValue: Double) -> Double {
        guard let value = self else {
            return defaultValue
        }
        return min(max(value, 0), 1)
    }
}

private extension TimeFieldStatus {
    init(llmValue: String?, hasValue: Bool) {
        switch llmValue?.lowercased() {
        case "confirmed": self = .confirmed
        case "inferred": self = .inferred
        case "missing": self = .missing
        case "needs_confirmation", "needsconfirmation": self = .needsConfirmation
        default: self = hasValue ? .inferred : .needsConfirmation
        }
    }
}

private extension LocationType {
    init(llmValue: String?) {
        switch llmValue?.lowercased() {
        case "physical": self = .physical
        case "online": self = .online
        case "phone": self = .phone
        case "not_applicable", "notapplicable": self = .notApplicable
        case "tbd": self = .tbd
        default: self = .tbd
        }
    }
}

private extension PriorityLevel {
    init(llmValue: String?) {
        switch llmValue?.lowercased() {
        case "low": self = .low
        case "medium": self = .medium
        case "high": self = .high
        case "critical": self = .critical
        default: self = .unknown
        }
    }
}

private extension CustomFieldType {
    init(llmValue: String?) {
        switch llmValue?.lowercased() {
        case "number": self = .number
        case "boolean": self = .boolean
        case "datetime": self = .datetime
        case "url": self = .url
        case "person": self = .person
        case "location": self = .location
        case "enum", "enumeration": self = .enumeration
        case "file": self = .file
        default: self = .string
        }
    }
}

private func makeAgendaFlowISO8601Formatter(fractionalSeconds: Bool) -> ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = fractionalSeconds ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
    return formatter
}
