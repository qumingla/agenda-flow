import Foundation
import SwiftData

enum RawInputType: String, Codable, CaseIterable, Identifiable, Sendable {
    case image
    case audio
    case text
    case file
    case url

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .image: "图片"
        case .audio: "音频"
        case .text: "文本"
        case .file: "文件"
        case .url: "链接"
        }
    }

    var iconName: String {
        switch self {
        case .image: "photo"
        case .audio: "waveform"
        case .text: "text.alignleft"
        case .file: "doc"
        case .url: "link"
        }
    }
}

enum InputSource: String, Codable, CaseIterable, Sendable {
    case appUpload
    case shareExtension
    case clipboard
    case voiceRecording
    case shortcut
    case manual

    var displayName: String {
        switch self {
        case .appUpload: "App 导入"
        case .shareExtension: "系统分享"
        case .clipboard: "剪贴板"
        case .voiceRecording: "录音"
        case .shortcut: "快捷指令"
        case .manual: "手动输入"
        }
    }
}

enum RawInputStatus: String, Codable, CaseIterable, Sendable {
    case captured
    case preprocessing
    case preprocessed
    case extracting
    case extracted
    case failed
    case archived
    case deleted

    var displayName: String {
        switch self {
        case .captured: "已捕获"
        case .preprocessing: "预处理中"
        case .preprocessed: "已预处理"
        case .extracting: "提取中"
        case .extracted: "已提取"
        case .failed: "失败"
        case .archived: "已归档"
        case .deleted: "已删除"
        }
    }
}

enum CandidateStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case draft
    case needsTime
    case needsLocation
    case lowConfidence
    case conflictDetected
    case readyForReview
    case approved
    case rejected
    case converted

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .draft: "草稿"
        case .needsTime: "缺少时间"
        case .needsLocation: "缺少地点"
        case .lowConfidence: "低置信度"
        case .conflictDetected: "有冲突"
        case .readyForReview: "可审核"
        case .approved: "已确认"
        case .rejected: "已忽略"
        case .converted: "已入日程"
        }
    }
}

enum TimeFieldStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case confirmed
    case inferred
    case missing
    case needsConfirmation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .confirmed: "已确认"
        case .inferred: "推断"
        case .missing: "缺失"
        case .needsConfirmation: "待确认"
        }
    }
}

enum LocationType: String, Codable, CaseIterable, Identifiable, Sendable {
    case physical
    case online
    case phone
    case tbd
    case notApplicable

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .physical: "线下地点"
        case .online: "线上会议"
        case .phone: "电话沟通"
        case .tbd: "待定"
        case .notApplicable: "不适用"
        }
    }

    var iconName: String {
        switch self {
        case .physical: "mappin.and.ellipse"
        case .online: "video"
        case .phone: "phone"
        case .tbd: "questionmark.circle"
        case .notApplicable: "minus.circle"
        }
    }
}

enum PriorityLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case low
    case medium
    case high
    case critical
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: "低"
        case .medium: "中"
        case .high: "高"
        case .critical: "紧急"
        case .unknown: "未知"
        }
    }
}

enum CustomFieldType: String, Codable, CaseIterable, Identifiable, Sendable {
    case string
    case number
    case boolean
    case datetime
    case url
    case person
    case location
    case enumeration
    case file

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .string: "文本"
        case .number: "数字"
        case .boolean: "开关"
        case .datetime: "日期时间"
        case .url: "链接"
        case .person: "人物"
        case .location: "地点"
        case .enumeration: "选项"
        case .file: "文件"
        }
    }
}

enum OwnerType: String, Codable, Sendable {
    case candidateEvent
    case calendarEvent
}

enum FieldSource: String, Codable, CaseIterable, Sendable {
    case llm
    case user
    case rule
    case integration
}

enum LockStatus: String, Codable, CaseIterable, Sendable {
    case unlocked
    case userLocked
    case systemLocked
}

enum CalendarEventStatus: String, Codable, CaseIterable, Sendable {
    case planned
    case notified
    case syncPending
    case synced
    case syncFailed
    case cancelled
    case deleted

    var displayName: String {
        switch self {
        case .planned: "已计划"
        case .notified: "已提醒"
        case .syncPending: "待同步"
        case .synced: "已同步"
        case .syncFailed: "同步失败"
        case .cancelled: "已取消"
        case .deleted: "已删除"
        }
    }
}

struct OCRBlock: Codable, Hashable, Sendable {
    var text: String
    var boundingBox: [Double]
    var confidence: Double
}

struct OCRResult: Sendable {
    var text: String
    var confidence: Double
    var blocks: [OCRBlock]
}

struct CustomFieldDraft: Sendable {
    var key: String
    var label: String
    var type: CustomFieldType
    var value: String
    var confidence: Double
    var sourceText: String
}

struct CandidateDraft: Sendable {
    var title: String
    var titleConfidence: Double
    var titleSourceText: String
    var startDate: Date?
    var endDate: Date?
    var timeStatus: TimeFieldStatus
    var timeSourceText: String
    var locationType: LocationType
    var locationName: String
    var locationAddress: String
    var locationStatus: TimeFieldStatus
    var locationSourceText: String
    var priority: PriorityLevel
    var urgencyReason: String
    var notes: String
    var sourceSummary: String
    var questions: [String]
    var confidence: Double
    var dynamicFields: [CustomFieldDraft]
}

@Model
final class RawInputModel: Identifiable {
    @Attribute(.unique) var id: UUID
    var inputTypeRaw: String
    var sourceRaw: String
    var createdAt: Date
    var originalFilePath: String?
    var thumbnailPath: String?
    var originalText: String?
    var rawText: String?
    var statusRaw: String
    var metadata: String
    var contentHash: String
    var failureReason: String?

    @Relationship(deleteRule: .cascade, inverse: \PreprocessResultModel.rawInput)
    var preprocessResults: [PreprocessResultModel] = []

    @Relationship(deleteRule: .cascade, inverse: \CandidateEventModel.rawInput)
    var candidates: [CandidateEventModel] = []

    init(
        id: UUID = UUID(),
        inputType: RawInputType,
        source: InputSource,
        createdAt: Date = Date(),
        originalFilePath: String? = nil,
        thumbnailPath: String? = nil,
        originalText: String? = nil,
        rawText: String? = nil,
        status: RawInputStatus = .captured,
        metadata: String = "{}",
        contentHash: String = ""
    ) {
        self.id = id
        self.inputTypeRaw = inputType.rawValue
        self.sourceRaw = source.rawValue
        self.createdAt = createdAt
        self.originalFilePath = originalFilePath
        self.thumbnailPath = thumbnailPath
        self.originalText = originalText
        self.rawText = rawText
        self.statusRaw = status.rawValue
        self.metadata = metadata
        self.contentHash = contentHash
    }

    var inputType: RawInputType {
        get { RawInputType(rawValue: inputTypeRaw) ?? .text }
        set { inputTypeRaw = newValue.rawValue }
    }

    var source: InputSource {
        get { InputSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var status: RawInputStatus {
        get { RawInputStatus(rawValue: statusRaw) ?? .captured }
        set { statusRaw = newValue.rawValue }
    }

    var displayText: String {
        let source = rawText ?? originalText ?? failureReason ?? "暂无可显示文本"
        return source.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@Model
final class PreprocessResultModel: Identifiable {
    @Attribute(.unique) var id: UUID
    var preprocessType: String
    var text: String
    var confidence: Double
    var blocksJSON: String
    var language: String
    var engineName: String
    var engineVersion: String
    var createdAt: Date
    var rawInput: RawInputModel?

    init(
        id: UUID = UUID(),
        rawInput: RawInputModel?,
        preprocessType: String,
        text: String,
        confidence: Double,
        blocksJSON: String = "[]",
        language: String = "zh-Hans",
        engineName: String,
        engineVersion: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.rawInput = rawInput
        self.preprocessType = preprocessType
        self.text = text
        self.confidence = confidence
        self.blocksJSON = blocksJSON
        self.language = language
        self.engineName = engineName
        self.engineVersion = engineVersion
        self.createdAt = createdAt
    }
}

@Model
final class CandidateEventModel: Identifiable {
    @Attribute(.unique) var id: UUID
    var titleValue: String
    var titleConfidence: Double
    var titleSourceText: String
    var startDate: Date?
    var endDate: Date?
    var timezoneIdentifier: String
    var isAllDay: Bool
    var timeStatusRaw: String
    var timeSourceText: String
    var locationTypeRaw: String
    var locationName: String
    var locationAddress: String
    var locationStatusRaw: String
    var locationSourceText: String
    var priorityRaw: String
    var urgencyReason: String
    var notes: String
    var overallConfidence: Double
    var statusRaw: String
    var sourceSummary: String
    var questionsBlob: String
    var lockedFieldsBlob: String
    var createdAt: Date
    var updatedAt: Date
    var rawInput: RawInputModel?

    init(
        id: UUID = UUID(),
        rawInput: RawInputModel?,
        titleValue: String,
        titleConfidence: Double,
        titleSourceText: String,
        startDate: Date?,
        endDate: Date?,
        timezoneIdentifier: String,
        isAllDay: Bool = false,
        timeStatus: TimeFieldStatus,
        timeSourceText: String,
        locationType: LocationType,
        locationName: String,
        locationAddress: String = "",
        locationStatus: TimeFieldStatus,
        locationSourceText: String,
        priority: PriorityLevel,
        urgencyReason: String,
        notes: String,
        overallConfidence: Double,
        status: CandidateStatus,
        sourceSummary: String,
        questions: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.rawInput = rawInput
        self.titleValue = titleValue
        self.titleConfidence = titleConfidence
        self.titleSourceText = titleSourceText
        self.startDate = startDate
        self.endDate = endDate
        self.timezoneIdentifier = timezoneIdentifier
        self.isAllDay = isAllDay
        self.timeStatusRaw = timeStatus.rawValue
        self.timeSourceText = timeSourceText
        self.locationTypeRaw = locationType.rawValue
        self.locationName = locationName
        self.locationAddress = locationAddress
        self.locationStatusRaw = locationStatus.rawValue
        self.locationSourceText = locationSourceText
        self.priorityRaw = priority.rawValue
        self.urgencyReason = urgencyReason
        self.notes = notes
        self.overallConfidence = overallConfidence
        self.statusRaw = status.rawValue
        self.sourceSummary = sourceSummary
        self.questionsBlob = questions.joined(separator: "\n")
        self.lockedFieldsBlob = ""
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var title: String {
        get { titleValue }
        set {
            titleValue = newValue
            touchAndLock("title")
        }
    }

    var timeStatus: TimeFieldStatus {
        get { TimeFieldStatus(rawValue: timeStatusRaw) ?? .missing }
        set {
            timeStatusRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    var locationType: LocationType {
        get { LocationType(rawValue: locationTypeRaw) ?? .tbd }
        set {
            locationTypeRaw = newValue.rawValue
            touchAndLock("location.type")
        }
    }

    var locationStatus: TimeFieldStatus {
        get { TimeFieldStatus(rawValue: locationStatusRaw) ?? .missing }
        set {
            locationStatusRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    var priority: PriorityLevel {
        get { PriorityLevel(rawValue: priorityRaw) ?? .unknown }
        set {
            priorityRaw = newValue.rawValue
            touchAndLock("priority")
        }
    }

    var status: CandidateStatus {
        get { CandidateStatus(rawValue: statusRaw) ?? .draft }
        set {
            statusRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    var questions: [String] {
        get { questionsBlob.split(separator: "\n").map(String.init) }
        set { questionsBlob = newValue.joined(separator: "\n") }
    }

    var lockedFields: Set<String> {
        get { Set(lockedFieldsBlob.split(separator: ",").map(String.init)) }
        set { lockedFieldsBlob = newValue.sorted().joined(separator: ",") }
    }

    func touchAndLock(_ key: String) {
        var fields = lockedFields
        fields.insert(key)
        lockedFields = fields
        updatedAt = Date()
    }
}

@Model
final class CustomFieldModel: Identifiable {
    @Attribute(.unique) var id: UUID
    var ownerTypeRaw: String
    var ownerID: UUID
    var key: String
    var label: String
    var typeRaw: String
    var value: String
    var sourceRaw: String
    var confidence: Double
    var isUserModified: Bool
    var lockStatusRaw: String
    var sourceText: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        ownerType: OwnerType,
        ownerID: UUID,
        key: String,
        label: String,
        type: CustomFieldType,
        value: String,
        source: FieldSource,
        confidence: Double = 1,
        isUserModified: Bool = false,
        lockStatus: LockStatus = .unlocked,
        sourceText: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownerTypeRaw = ownerType.rawValue
        self.ownerID = ownerID
        self.key = key
        self.label = label
        self.typeRaw = type.rawValue
        self.value = value
        self.sourceRaw = source.rawValue
        self.confidence = confidence
        self.isUserModified = isUserModified
        self.lockStatusRaw = lockStatus.rawValue
        self.sourceText = sourceText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var ownerType: OwnerType {
        get { OwnerType(rawValue: ownerTypeRaw) ?? .candidateEvent }
        set { ownerTypeRaw = newValue.rawValue }
    }

    var fieldType: CustomFieldType {
        get { CustomFieldType(rawValue: typeRaw) ?? .string }
        set {
            typeRaw = newValue.rawValue
            markUserModified()
        }
    }

    var source: FieldSource {
        get { FieldSource(rawValue: sourceRaw) ?? .user }
        set { sourceRaw = newValue.rawValue }
    }

    var lockStatus: LockStatus {
        get { LockStatus(rawValue: lockStatusRaw) ?? .unlocked }
        set { lockStatusRaw = newValue.rawValue }
    }

    func markUserModified() {
        isUserModified = true
        source = .user
        lockStatus = .userLocked
        updatedAt = Date()
    }
}

@Model
final class CalendarEventModel: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var timezoneIdentifier: String
    var isAllDay: Bool
    var locationTypeRaw: String
    var locationName: String
    var locationAddress: String
    var notes: String
    var priorityRaw: String
    var sourceCandidateID: UUID?
    var sourceRawInputIDsBlob: String
    var remindersBlob: String
    var statusRaw: String
    var userModifiedFieldsBlob: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date,
        timezoneIdentifier: String,
        isAllDay: Bool = false,
        locationType: LocationType,
        locationName: String,
        locationAddress: String,
        notes: String,
        priority: PriorityLevel,
        sourceCandidateID: UUID?,
        sourceRawInputIDs: [UUID],
        reminders: [Int],
        status: CalendarEventStatus = .planned,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.timezoneIdentifier = timezoneIdentifier
        self.isAllDay = isAllDay
        self.locationTypeRaw = locationType.rawValue
        self.locationName = locationName
        self.locationAddress = locationAddress
        self.notes = notes
        self.priorityRaw = priority.rawValue
        self.sourceCandidateID = sourceCandidateID
        self.sourceRawInputIDsBlob = sourceRawInputIDs.map(\.uuidString).joined(separator: ",")
        self.remindersBlob = reminders.map(String.init).joined(separator: ",")
        self.statusRaw = status.rawValue
        self.userModifiedFieldsBlob = ""
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var locationType: LocationType {
        get { LocationType(rawValue: locationTypeRaw) ?? .tbd }
        set {
            locationTypeRaw = newValue.rawValue
            touch("location.type")
        }
    }

    var priority: PriorityLevel {
        get { PriorityLevel(rawValue: priorityRaw) ?? .unknown }
        set {
            priorityRaw = newValue.rawValue
            touch("priority")
        }
    }

    var status: CalendarEventStatus {
        get { CalendarEventStatus(rawValue: statusRaw) ?? .planned }
        set {
            statusRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    var reminders: [Int] {
        get {
            remindersBlob
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
        set { remindersBlob = newValue.map(String.init).joined(separator: ",") }
    }

    func touch(_ key: String) {
        var fields = Set(userModifiedFieldsBlob.split(separator: ",").map(String.init))
        fields.insert(key)
        userModifiedFieldsBlob = fields.sorted().joined(separator: ",")
        updatedAt = Date()
    }
}

@Model
final class LLMTraceModel: Identifiable {
    @Attribute(.unique) var id: UUID
    var rawInputID: UUID?
    var candidateEventID: UUID?
    var taskType: String
    var inputHash: String
    var promptVersion: String
    var schemaVersion: String
    var modelProvider: String
    var modelName: String
    var rawResponse: String
    var parsedResponse: String
    var latencyMS: Int
    var tokenUsage: String
    var costEstimate: Double
    var error: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        rawInputID: UUID?,
        candidateEventID: UUID? = nil,
        taskType: String,
        inputHash: String,
        promptVersion: String,
        schemaVersion: String,
        modelProvider: String,
        modelName: String,
        rawResponse: String,
        parsedResponse: String,
        latencyMS: Int,
        tokenUsage: String = "{}",
        costEstimate: Double = 0,
        error: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.rawInputID = rawInputID
        self.candidateEventID = candidateEventID
        self.taskType = taskType
        self.inputHash = inputHash
        self.promptVersion = promptVersion
        self.schemaVersion = schemaVersion
        self.modelProvider = modelProvider
        self.modelName = modelName
        self.rawResponse = rawResponse
        self.parsedResponse = parsedResponse
        self.latencyMS = latencyMS
        self.tokenUsage = tokenUsage
        self.costEstimate = costEstimate
        self.error = error
        self.createdAt = createdAt
    }
}
