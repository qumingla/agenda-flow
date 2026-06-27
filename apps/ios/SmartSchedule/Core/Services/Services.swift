import CryptoKit
import Foundation
import ImageIO
import SwiftData
import SwiftUI
import UIKit
import UserNotifications
@preconcurrency import Vision

enum BetaAppError: LocalizedError {
    case emptyInput
    case imageDecodingFailed
    case ocrFailed
    case missingStartDate
    case invalidLocation
    case fileWriteFailed
    case invalidLLMConfiguration(String)
    case keychainFailed(String)
    case llmRequestFailed(String)
    case invalidLLMResponse(String)

    var errorDescription: String? {
        switch self {
        case .emptyInput: "输入内容为空。"
        case .imageDecodingFailed: "图片无法读取。"
        case .ocrFailed: "OCR 未能识别出可用文本。"
        case .missingStartDate: "提交前必须确认明确时间。"
        case .invalidLocation: "线下地点需要填写地点名称，或将地点类型改为待定/不适用。"
        case .fileWriteFailed: "文件保存失败。"
        case .invalidLLMConfiguration(let message): "LLM 配置不可用：\(message)"
        case .keychainFailed(let message): "密钥保存失败：\(message)"
        case .llmRequestFailed(let message): "LLM 请求失败：\(message)"
        case .invalidLLMResponse(let message): "LLM 返回格式不可用：\(message)"
        }
    }
}

struct LLMExtractionResult: Sendable {
    var drafts: [CandidateDraft]
    var promptVersion: String
    var schemaVersion: String
    var modelProvider: String
    var modelName: String
    var rawResponse: String
    var parsedResponse: String
    var tokenUsage: String
    var costEstimate: Double

    init(
        drafts: [CandidateDraft],
        promptVersion: String,
        schemaVersion: String = "1.0",
        modelProvider: String,
        modelName: String,
        rawResponse: String,
        parsedResponse: String,
        tokenUsage: String = "{}",
        costEstimate: Double = 0
    ) {
        self.drafts = drafts
        self.promptVersion = promptVersion
        self.schemaVersion = schemaVersion
        self.modelProvider = modelProvider
        self.modelName = modelName
        self.rawResponse = rawResponse
        self.parsedResponse = parsedResponse
        self.tokenUsage = tokenUsage
        self.costEstimate = costEstimate
    }
}

@MainActor
protocol OCRService {
    func recognizeText(from imageURL: URL) async throws -> OCRResult
}

@MainActor
protocol LLMService {
    func extractCandidates(from text: String, referenceDate: Date) async throws -> LLMExtractionResult
}

protocol CalendarSyncService {
    func createEvent(_ event: CalendarEventModel) async throws -> String
    func updateEvent(_ event: CalendarEventModel) async throws
    func deleteEvent(_ externalID: String) async throws
}

struct BetaHash {
    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func sha256(_ string: String) -> String {
        sha256(Data(string.utf8))
    }
}

struct LocalFileStorageService {
    enum StoredKind: String {
        case image = "raw_inputs/images"
        case thumbnail = "processed/thumbnails"
    }

    func save(_ data: Data, kind: StoredKind, extension fileExtension: String) throws -> String {
        let directory = try ensureDirectory(kind)
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        let url = directory.appendingPathComponent(fileName)

        do {
            try data.write(to: url, options: [.atomic])
            return url.path
        } catch {
            throw BetaAppError.fileWriteFailed
        }
    }

    func makeThumbnail(from imageData: Data) throws -> String? {
        guard let image = UIImage(data: imageData) else {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 360, height: 360))
        let thumbnail = renderer.image { _ in
            let scale = max(360 / image.size.width, 360 / image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(x: (360 - size.width) / 2, y: (360 - size.height) / 2)
            image.draw(in: CGRect(origin: origin, size: size))
        }

        guard let jpeg = thumbnail.jpegData(compressionQuality: 0.78) else {
            return nil
        }

        return try save(jpeg, kind: .thumbnail, extension: "jpg")
    }

    private func ensureDirectory(_ kind: StoredKind) throws -> URL {
        let root = URL.documentsDirectory.appendingPathComponent(kind.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}

@MainActor
struct AppleVisionOCRService: OCRService {
    func recognizeText(from imageURL: URL) async throws -> OCRResult {
        guard let image = UIImage(contentsOfFile: imageURL.path),
              let cgImage = image.cgImage else {
            throw BetaAppError.imageDecodingFailed
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation))
        try handler.perform([request])

        let observations = request.results ?? []
        let blocks = observations.compactMap { observation -> OCRBlock? in
            guard let candidate = observation.topCandidates(1).first else {
                return nil
            }
            return OCRBlock(
                text: candidate.string,
                boundingBox: [
                    observation.boundingBox.origin.x,
                    observation.boundingBox.origin.y,
                    observation.boundingBox.size.width,
                    observation.boundingBox.size.height
                ],
                confidence: Double(candidate.confidence)
            )
        }

        let text = blocks.map(\.text).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw BetaAppError.ocrFailed
        }

        let confidence = blocks.isEmpty ? 0 : blocks.map(\.confidence).reduce(0, +) / Double(blocks.count)
        return OCRResult(text: text, confidence: confidence, blocks: blocks)
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

@MainActor
struct MockLLMService: LLMService {
    func extractCandidates(from text: String, referenceDate: Date) async throws -> LLMExtractionResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BetaAppError.emptyInput
        }

        let chunks = splitPotentialEvents(trimmed)
        let drafts = chunks.compactMap { chunk in
            makeDraft(from: chunk, referenceDate: referenceDate)
        }

        let finalDrafts: [CandidateDraft]
        if drafts.isEmpty, looksLikeSchedule(trimmed) {
            finalDrafts = [fallbackDraft(from: trimmed, referenceDate: referenceDate)]
        } else {
            finalDrafts = drafts
        }

        return LLMExtractionResult(
            drafts: finalDrafts,
            promptVersion: "mock-extraction-v1",
            modelProvider: "local",
            modelName: "MockLLMService",
            rawResponse: "Generated \(finalDrafts.count) candidate(s)",
            parsedResponse: finalDrafts.map(\.title).joined(separator: ", ")
        )
    }

    private func splitPotentialEvents(_ text: String) -> [String] {
        let separators = CharacterSet(charactersIn: "\n。；;")
        return text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func makeDraft(from text: String, referenceDate: Date) -> CandidateDraft? {
        guard looksLikeSchedule(text) else {
            return nil
        }

        let parsedDate = parseDateTime(from: text, referenceDate: referenceDate)
        let location = parseLocation(from: text)
        let dynamicFields = parseDynamicFields(from: text)
        let title = parseTitle(from: text, dynamicFields: dynamicFields)
        let priority = parsePriority(from: text)
        let missingQuestions = questions(startDate: parsedDate.date, location: location)

        return CandidateDraft(
            title: title,
            titleConfidence: title == "待确认日程" ? 0.45 : 0.76,
            titleSourceText: text,
            startDate: parsedDate.date,
            endDate: parsedDate.date.map { Calendar.current.date(byAdding: .minute, value: 60, to: $0) ?? $0 },
            timeStatus: parsedDate.date == nil ? .needsConfirmation : parsedDate.status,
            timeSourceText: parsedDate.sourceText,
            locationType: location.type,
            locationName: location.name,
            locationAddress: "",
            locationStatus: location.status,
            locationSourceText: location.sourceText,
            priority: priority.level,
            urgencyReason: priority.reason,
            notes: buildNotes(from: text, dynamicFields: dynamicFields),
            sourceSummary: "从输入中识别到可能的日程：\(title)",
            questions: missingQuestions,
            confidence: confidence(time: parsedDate.date, location: location, title: title),
            dynamicFields: dynamicFields
        )
    }

    private func fallbackDraft(from text: String, referenceDate: Date) -> CandidateDraft {
        let parsedDate = parseDateTime(from: text, referenceDate: referenceDate)
        let location = parseLocation(from: text)
        return CandidateDraft(
            title: parseTitle(from: text, dynamicFields: []),
            titleConfidence: 0.48,
            titleSourceText: text,
            startDate: parsedDate.date,
            endDate: parsedDate.date.map { Calendar.current.date(byAdding: .minute, value: 60, to: $0) ?? $0 },
            timeStatus: parsedDate.date == nil ? .needsConfirmation : parsedDate.status,
            timeSourceText: parsedDate.sourceText,
            locationType: location.type,
            locationName: location.name,
            locationAddress: "",
            locationStatus: location.status,
            locationSourceText: location.sourceText,
            priority: .unknown,
            urgencyReason: "Beta 规则提取未发现明确优先级。",
            notes: text,
            sourceSummary: "输入看起来包含日程信息，但需要人工确认。",
            questions: questions(startDate: parsedDate.date, location: location),
            confidence: 0.42,
            dynamicFields: parseDynamicFields(from: text)
        )
    }

    private func looksLikeSchedule(_ text: String) -> Bool {
        let markers = [
            "今天", "明天", "后天", "周", "星期", "下周", "上午", "下午", "晚上",
            "点", "会议", "开会", "见", "约", "截止", "提醒", "deadline",
            "meeting", "call", "tomorrow", "today"
        ]
        return markers.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func parseDateTime(from text: String, referenceDate: Date) -> (date: Date?, status: TimeFieldStatus, sourceText: String) {
        var calendar = Calendar.current
        calendar.timeZone = .current
        let baseStart = calendar.startOfDay(for: referenceDate)
        var dayOffset = 0
        var sourceParts: [String] = []

        if text.contains("后天") {
            dayOffset = 2
            sourceParts.append("后天")
        } else if text.contains("明天") {
            dayOffset = 1
            sourceParts.append("明天")
        } else if text.contains("今天") {
            dayOffset = 0
            sourceParts.append("今天")
        } else if let weekday = weekdayOffset(in: text, referenceDate: referenceDate, calendar: calendar) {
            dayOffset = weekday.offset
            sourceParts.append(weekday.source)
        } else if text.localizedCaseInsensitiveContains("tomorrow") {
            dayOffset = 1
            sourceParts.append("tomorrow")
        } else if text.localizedCaseInsensitiveContains("today") {
            dayOffset = 0
            sourceParts.append("today")
        }

        guard let time = parseClock(from: text) else {
            if sourceParts.isEmpty {
                return (nil, .missing, "")
            }
            return (calendar.date(byAdding: .day, value: dayOffset, to: baseStart), .needsConfirmation, sourceParts.joined(separator: " "))
        }

        var components = DateComponents()
        components.day = dayOffset
        components.hour = time.hour
        components.minute = time.minute
        let date = calendar.date(byAdding: components, to: baseStart)
        sourceParts.append(time.source)
        return (date, .inferred, sourceParts.joined(separator: " "))
    }

    private func weekdayOffset(in text: String, referenceDate: Date, calendar: Calendar) -> (offset: Int, source: String)? {
        let mapping: [(String, Int)] = [
            ("周一", 2), ("星期一", 2),
            ("周二", 3), ("星期二", 3),
            ("周三", 4), ("星期三", 4),
            ("周四", 5), ("星期四", 5),
            ("周五", 6), ("星期五", 6),
            ("周六", 7), ("星期六", 7),
            ("周日", 1), ("星期日", 1), ("周天", 1), ("星期天", 1)
        ]

        guard let match = mapping.first(where: { text.contains($0.0) }) else {
            return nil
        }

        let currentWeekday = calendar.component(.weekday, from: referenceDate)
        let offset = (match.1 - currentWeekday + 7) % 7
        return (offset == 0 ? 7 : offset, match.0)
    }

    private func parseClock(from text: String) -> (hour: Int, minute: Int, source: String)? {
        let normalized = text.replacingOccurrences(of: "：", with: ":")
        let pattern = #"(?:(上午|下午|晚上|早上|中午)\s*)?(\d{1,2})(?:[:点时](\d{1,2})?分?)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        guard let match = regex.matches(in: normalized, range: range).first(where: { result in
            result.range(at: 0).location != NSNotFound
        }) else {
            return nil
        }

        func substring(_ index: Int) -> String {
            guard match.range(at: index).location != NSNotFound,
                  let range = Range(match.range(at: index), in: normalized) else {
                return ""
            }
            return String(normalized[range])
        }

        let meridiem = substring(1)
        guard var hour = Int(substring(2)) else {
            return nil
        }
        let minute = Int(substring(3)) ?? 0

        if ["下午", "晚上"].contains(meridiem), hour < 12 {
            hour += 12
        }
        if meridiem == "中午", hour < 11 {
            hour += 12
        }

        let source = substring(0)
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute, source)
    }

    private func parseLocation(from text: String) -> (type: LocationType, name: String, status: TimeFieldStatus, sourceText: String) {
        if let url = firstURL(in: text) {
            return (.online, url, .confirmed, url)
        }

        let cues = ["在", "地点", "地址", "到"]
        for cue in cues {
            guard let range = text.range(of: cue) else {
                continue
            }
            let suffix = String(text[range.upperBound...])
            let delimiters = CharacterSet(charactersIn: "，,。；; ")
            let name = suffix.components(separatedBy: delimiters).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if name.count >= 2 {
                return (.physical, name, .inferred, "\(cue)\(name)")
            }
        }

        if text.contains("电话") || text.localizedCaseInsensitiveContains("call") {
            return (.phone, "电话沟通", .inferred, "电话")
        }

        if text.contains("线上") || text.contains("腾讯会议") || text.contains("Zoom") || text.contains("飞书会议") {
            return (.online, "线上会议", .inferred, "线上会议")
        }

        return (.tbd, "", .needsConfirmation, "")
    }

    private func firstURL(in text: String) -> String? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.firstMatch(in: text, range: range)?.url?.absoluteString
    }

    private func parsePriority(from text: String) -> (level: PriorityLevel, reason: String) {
        if text.contains("紧急") || text.contains("马上") || text.localizedCaseInsensitiveContains("urgent") {
            return (.critical, "原文包含紧急语气。")
        }
        if text.contains("别忘") || text.contains("提醒") || text.contains("截止") || text.localizedCaseInsensitiveContains("deadline") {
            return (.high, "原文包含提醒或截止信息。")
        }
        return (.medium, "Beta 默认优先级。")
    }

    private func parseDynamicFields(from text: String) -> [CustomFieldDraft] {
        var fields: [CustomFieldDraft] = []

        if let material = capture(after: "带", in: text) ?? capture(after: "携带", in: text) {
            fields.append(CustomFieldDraft(
                key: "materials_to_bring",
                label: "需携带材料",
                type: .string,
                value: material,
                confidence: 0.82,
                sourceText: material
            ))
        }

        if let url = firstURL(in: text) {
            fields.append(CustomFieldDraft(
                key: "meeting_link",
                label: "会议链接",
                type: .url,
                value: url,
                confidence: 0.92,
                sourceText: url
            ))
        }

        if text.contains("合同") {
            fields.append(CustomFieldDraft(
                key: "topic",
                label: "相关主题",
                type: .string,
                value: "合同",
                confidence: 0.7,
                sourceText: "合同"
            ))
        }

        return fields
    }

    private func capture(after marker: String, in text: String) -> String? {
        guard let range = text.range(of: marker) else {
            return nil
        }
        let suffix = String(text[range.upperBound...])
        let delimiters = CharacterSet(charactersIn: "，,。；; ")
        let value = suffix.components(separatedBy: delimiters).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    private func parseTitle(from text: String, dynamicFields: [CustomFieldDraft]) -> String {
        if text.contains("合同") && (text.contains("会议") || text.contains("讨论")) {
            return "合同讨论会议"
        }
        if text.contains("开会") || text.contains("会议") {
            return "会议"
        }
        if text.contains("见") || text.contains("约") {
            return "见面安排"
        }
        if text.contains("截止") {
            return "截止事项"
        }
        if let topic = dynamicFields.first(where: { $0.key == "topic" })?.value {
            return "\(topic)安排"
        }
        return "待确认日程"
    }

    private func buildNotes(from text: String, dynamicFields: [CustomFieldDraft]) -> String {
        var notes = [text]
        let material = dynamicFields.first { $0.key == "materials_to_bring" }?.value
        if let material {
            notes.append("需携带：\(material)")
        }
        return notes.joined(separator: "\n")
    }

    private func questions(
        startDate: Date?,
        location: (type: LocationType, name: String, status: TimeFieldStatus, sourceText: String)
    ) -> [String] {
        var questions: [String] = []
        if startDate == nil {
            questions.append("这个日程的明确开始时间是什么？")
        }
        if location.type == .tbd {
            questions.append("地点是线下、线上、电话，还是不适用？")
        }
        return questions
    }

    private func confidence(
        time: Date?,
        location: (type: LocationType, name: String, status: TimeFieldStatus, sourceText: String),
        title: String
    ) -> Double {
        var score = 0.35
        if time != nil {
            score += 0.25
        }
        if location.type != .tbd {
            score += 0.18
        }
        if title != "待确认日程" {
            score += 0.14
        }
        return min(score, 0.92)
    }
}

@MainActor
struct BetaExtractionPipeline {
    var ocrService: OCRService = AppleVisionOCRService()
    var llmService: (any LLMService)?

    func processText(rawInput: RawInputModel, context: ModelContext) async {
        await extract(from: rawInput.originalText ?? rawInput.rawText ?? "", rawInput: rawInput, context: context)
    }

    func processImage(rawInput: RawInputModel, context: ModelContext) async {
        guard let path = rawInput.originalFilePath else {
            rawInput.status = .failed
            rawInput.failureReason = "缺少图片文件。"
            try? context.save()
            return
        }

        do {
            rawInput.status = .preprocessing
            try context.save()

            let result = try await ocrService.recognizeText(from: URL(fileURLWithPath: path))
            let blocksData = try JSONEncoder().encode(result.blocks)
            let blocksJSON = String(decoding: blocksData, as: UTF8.self)
            let preprocess = PreprocessResultModel(
                rawInput: rawInput,
                preprocessType: "ocr",
                text: result.text,
                confidence: result.confidence,
                blocksJSON: blocksJSON,
                engineName: "Apple Vision",
                engineVersion: "iOS 26"
            )
            rawInput.preprocessResults.append(preprocess)
            rawInput.rawText = result.text
            rawInput.status = .preprocessed
            context.insert(preprocess)
            try context.save()

            await extract(from: result.text, rawInput: rawInput, context: context)
        } catch {
            rawInput.status = .failed
            rawInput.failureReason = error.localizedDescription
            try? context.save()
        }
    }

    private func extract(from text: String, rawInput: RawInputModel, context: ModelContext) async {
        do {
            rawInput.status = .extracting
            try context.save()
            let started = Date()
            let service = try llmService ?? LLMServiceFactory.makeService()
            let result = try await service.extractCandidates(from: text, referenceDate: rawInput.createdAt)
            let drafts = result.drafts

            for draft in drafts {
                let candidate = CandidateEventModel(
                    rawInput: rawInput,
                    titleValue: draft.title,
                    titleConfidence: draft.titleConfidence,
                    titleSourceText: draft.titleSourceText,
                    startDate: draft.startDate,
                    endDate: draft.endDate,
                    timezoneIdentifier: TimeZone.current.identifier,
                    timeStatus: draft.timeStatus,
                    timeSourceText: draft.timeSourceText,
                    locationType: draft.locationType,
                    locationName: draft.locationName,
                    locationAddress: draft.locationAddress,
                    locationStatus: draft.locationStatus,
                    locationSourceText: draft.locationSourceText,
                    priority: draft.priority,
                    urgencyReason: draft.urgencyReason,
                    notes: draft.notes,
                    overallConfidence: draft.confidence,
                    status: status(for: draft),
                    sourceSummary: draft.sourceSummary,
                    questions: draft.questions
                )
                context.insert(candidate)
                rawInput.candidates.append(candidate)

                for fieldDraft in draft.dynamicFields {
                    context.insert(CustomFieldModel(
                        ownerType: .candidateEvent,
                        ownerID: candidate.id,
                        key: fieldDraft.key,
                        label: fieldDraft.label,
                        type: fieldDraft.type,
                        value: fieldDraft.value,
                        source: .llm,
                        confidence: fieldDraft.confidence,
                        sourceText: fieldDraft.sourceText
                    ))
                }
            }

            let latency = Int(Date().timeIntervalSince(started) * 1000)
            context.insert(LLMTraceModel(
                rawInputID: rawInput.id,
                taskType: "extraction",
                inputHash: BetaHash.sha256(text),
                promptVersion: result.promptVersion,
                schemaVersion: result.schemaVersion,
                modelProvider: result.modelProvider,
                modelName: result.modelName,
                rawResponse: result.rawResponse,
                parsedResponse: result.parsedResponse,
                latencyMS: latency,
                tokenUsage: result.tokenUsage,
                costEstimate: result.costEstimate
            ))

            rawInput.status = drafts.isEmpty ? .failed : .extracted
            if drafts.isEmpty {
                rawInput.failureReason = "未识别到日程候选。"
            }
            try context.save()
        } catch {
            rawInput.status = .failed
            rawInput.failureReason = error.localizedDescription
            context.insert(LLMTraceModel(
                rawInputID: rawInput.id,
                taskType: "extraction",
                inputHash: BetaHash.sha256(text),
                promptVersion: "extraction-v1",
                schemaVersion: "1.0",
                modelProvider: "unknown",
                modelName: "unknown",
                rawResponse: "",
                parsedResponse: "",
                latencyMS: 0,
                error: error.localizedDescription
            ))
            try? context.save()
        }
    }

    private func status(for draft: CandidateDraft) -> CandidateStatus {
        if draft.startDate == nil {
            return .needsTime
        }
        if draft.locationType == .tbd {
            return .needsLocation
        }
        if draft.confidence < 0.55 {
            return .lowConfidence
        }
        return .readyForReview
    }
}

@MainActor
struct BetaPlanningService {
    func createCalendarEvent(
        from candidate: CandidateEventModel,
        context: ModelContext,
        defaultDurationMinutes: Int,
        defaultReminderMinutes: Int
    ) throws -> CalendarEventModel {
        guard let startDate = candidate.startDate else {
            throw BetaAppError.missingStartDate
        }
        if candidate.locationType == .physical,
           candidate.locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw BetaAppError.invalidLocation
        }

        let endDate = candidate.endDate ?? Calendar.current.date(
            byAdding: .minute,
            value: max(defaultDurationMinutes, 15),
            to: startDate
        ) ?? startDate.addingTimeInterval(3600)

        let event = CalendarEventModel(
            title: candidate.titleValue.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: endDate,
            timezoneIdentifier: candidate.timezoneIdentifier,
            isAllDay: candidate.isAllDay,
            locationType: candidate.locationType,
            locationName: candidate.locationName,
            locationAddress: candidate.locationAddress,
            notes: candidate.notes,
            priority: candidate.priority,
            sourceCandidateID: candidate.id,
            sourceRawInputIDs: candidate.rawInput.map { [$0.id] } ?? [],
            reminders: defaultReminderMinutes > 0 ? [defaultReminderMinutes] : []
        )

        context.insert(event)
        try copyDynamicFields(from: candidate, to: event, context: context)
        candidate.status = .converted
        try context.save()
        return event
    }

    private func copyDynamicFields(
        from candidate: CandidateEventModel,
        to event: CalendarEventModel,
        context: ModelContext
    ) throws {
        let candidateID = candidate.id
        let descriptor = FetchDescriptor<CustomFieldModel>(
            predicate: #Predicate { field in
                field.ownerID == candidateID && field.ownerTypeRaw == "candidateEvent"
            }
        )

        let fields = try context.fetch(descriptor)
        for field in fields {
            context.insert(CustomFieldModel(
                ownerType: .calendarEvent,
                ownerID: event.id,
                key: field.key,
                label: field.label,
                type: field.fieldType,
                value: field.value,
                source: field.source,
                confidence: field.confidence,
                isUserModified: field.isUserModified,
                lockStatus: field.lockStatus,
                sourceText: field.sourceText
            ))
        }
    }
}

struct NotificationEventSnapshot: Sendable {
    var id: UUID
    var title: String
    var startDate: Date
    var locationName: String
    var reminders: [Int]

    init(event: CalendarEventModel) {
        id = event.id
        title = event.title
        startDate = event.startDate
        locationName = event.locationName
        reminders = event.reminders
    }
}

struct NotificationScheduler {
    func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            return true
        }

        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func scheduleNotifications(for event: NotificationEventSnapshot) async {
        guard await requestAuthorizationIfNeeded() else {
            return
        }

        let center = UNUserNotificationCenter.current()
        for minutes in event.reminders {
            let triggerDate = event.startDate.addingTimeInterval(TimeInterval(-minutes * 60))
            guard triggerDate > Date() else {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = event.locationName.isEmpty ? "即将开始" : event.locationName
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "\(event.id.uuidString)-\(minutes)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}

struct StubCalendarSyncService: CalendarSyncService {
    func createEvent(_ event: CalendarEventModel) async throws -> String {
        throw BetaAppError.emptyInput
    }

    func updateEvent(_ event: CalendarEventModel) async throws {
        throw BetaAppError.emptyInput
    }

    func deleteEvent(_ externalID: String) async throws {
        throw BetaAppError.emptyInput
    }
}
