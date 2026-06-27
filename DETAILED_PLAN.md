# 随身多模态日程表详细实施计划

计划日期：2026-06-27
目标平台：iOS 优先，后续扩展 iPadOS、macOS、Web、Android
产品定位：多来源智能日程收集箱，把截图、文本、录音、文件中的潜在日程转换为可审核、可规划、可同步的结构化事件。

## 1. 总体结论

本项目不应从“再做一个日历”开始，而应从“低摩擦捕获 + 可追溯识别 + 人工审核 + 规划入库”开始。核心链路必须保证：

1. 所有输入先进入 Inbox，不直接创建正式日程。
2. OCR、ASR、LLM 只产出候选日程，不直接写入内置日程表或系统日历。
3. 用户审核后的字段优先级高于模型输出。
4. 提交正式日程前必须通过确定性规则校验。
5. 原始输入、预处理结果、LLM 输出、用户修改、规划结果都可追溯。
6. 隐私默认本地优先，云端模型处理必须由用户明确启用。

第一版建议做成“可靠的人机协作型智能日程收集箱”，暂不追求全自动后台识别、自动读取聊天记录、自动电话录音、复杂多端同步。

## 2. MVP 范围

### 2.1 MVP 必做

1. SwiftUI App 基础架构。
2. Inbox 原始资料收集箱。
3. 文本输入和剪贴板解析。
4. 图片选择和本地 OCR。
5. MockLLMService 到候选日程的完整闭环。
6. 可替换的 LLMService 协议。
7. 待审核列表和审核详情。
8. 固定字段编辑：标题、时间、地点、优先级、备注、提醒。
9. 动态字段编辑：新增、修改、删除、类型切换。
10. 提交审核后生成内置日程。
11. 内置日程表的今日视图和列表视图。
12. 本地通知提醒。
13. 基础设置：默认提醒、默认时长、工作时间、隐私模式。
14. 原始输入追溯：正式日程能回看来源。

### 2.2 MVP 可选

1. OpenAI 真实调用。
2. EventKit 同步。
3. Share Extension。
4. 音频导入和语音转文字。
5. 冲突检测。

### 2.3 MVP 暂不做

1. 自动读取微信、短信、WhatsApp 等 App 的聊天记录。
2. 后台自动读取所有截图。
3. 自动电话录音识别。
4. Google Calendar 和 Outlook 同步。
5. 多人协作。
6. Android 和 Web 客户端。
7. 账号系统和订阅计费。
8. 全自动无审核写入日历。

## 3. 产品原则

1. 用户确认优先于 LLM 判断。
2. LLM 只做建议，不直接写入最终日历。
3. 任何关键字段都必须能追溯到原始输入或用户编辑。
4. 时间和地点在正式提交前必须达到可用状态。
5. 动态字段必须可编辑、可删除、可重命名。
6. 核心数据模型不能绑定单一平台实现。
7. 外部能力全部通过 Adapter 接入。
8. Prompt、Schema、模型版本纳入 Git 管理。
9. 默认本地优先，云端处理清晰告知。
10. 先做可靠闭环，再做自动化。

## 4. 用户主流程

### 4.1 核心状态机

```text
输入捕获
  -> 原始资料 Inbox
  -> 预处理：OCR / ASR / 文本清洗 / 语言识别
  -> LLM 初次结构化提取
  -> 待审核草稿
  -> 用户编辑、补充、删除字段
  -> 提交审核结果
  -> 规则校验 + 可选 LLM 二次规划
  -> 生成正式日程
  -> 写入内置日程表
  -> 可选同步系统日历
  -> 后续编辑 / 重新规划 / 重新同步
```

### 4.2 状态定义

RawInput 状态：

1. captured：已捕获，未处理。
2. preprocessing：OCR、ASR 或文本清洗中。
3. preprocessed：预处理完成。
4. extracting：LLM 结构化提取中。
5. extracted：提取完成。
6. failed：处理失败，可重试。
7. archived：用户归档。
8. deleted：用户删除。

CandidateEvent 状态：

1. draft：模型生成，尚未审核。
2. needs_time：缺少明确时间。
3. needs_location：缺少地点状态。
4. low_confidence：整体置信度不足。
5. conflict_detected：检测到冲突。
6. ready_for_review：可审核。
7. approved：用户确认。
8. rejected：用户标记不是日程。
9. converted：已生成正式日程。

CalendarEvent 状态：

1. planned：已进入内置日程表。
2. notified：已创建本地提醒。
3. sync_pending：等待同步系统日历。
4. synced：已同步。
5. sync_failed：同步失败。
6. cancelled：已取消。
7. deleted：已删除。

## 5. 推荐仓库结构

初期可以先在当前目录建立如下结构：

```text
.
  README.md
  DETAILED_PLAN.md
  docs/
    product/
      PRD.md
      user-flows.md
      roadmap.md
    architecture/
      architecture-overview.md
      data-model.md
      llm-pipeline.md
      privacy-security.md
      adr/
        0001-ios-first.md
        0002-local-first-storage.md
        0003-llm-provider-abstraction.md
    design/
      wireframes/
      screenshots/
  schemas/
    extraction-result.schema.json
    candidate-event.schema.json
    planning-result.schema.json
    calendar-event.schema.json
  prompts/
    extraction/
      v1.md
    planning/
      v1.md
    repair/
      v1.md
  evals/
    fixtures/
      screenshots/
      transcripts/
      text_inputs/
    expected_outputs/
    README.md
  apps/
    ios/
      SmartSchedule.xcodeproj
      SmartSchedule/
        App/
        Features/
          Inbox/
          Capture/
          Review/
          Calendar/
          Settings/
        Core/
          Models/
          UseCases/
          Repositories/
          Services/
        Integrations/
          OCR/
          ASR/
          LLM/
          Calendar/
        Resources/
      SmartScheduleShareExtension/
      SmartScheduleTests/
      SmartScheduleUITests/
  packages/
    CoreModels/
    ScheduleEngine/
    LLMContracts/
    TestSupport/
  backend/
    README.md
    src/
    tests/
  .github/
    workflows/
      ios-ci.yml
      backend-ci.yml
```

实际落地时可以先只创建 `apps/ios`、`schemas`、`prompts`、`docs`，后端目录等需要时再补。

## 6. 技术架构

### 6.1 分层架构

App Layer：

1. SwiftUI Views。
2. Navigation。
3. ViewModels。
4. App lifecycle。
5. 权限请求入口。

Domain Layer：

1. RawInput。
2. PreprocessResult。
3. CandidateEvent。
4. CalendarEvent。
5. CustomField。
6. ReviewSession。
7. PlanningResult。
8. Use Cases。

Service Layer：

1. OCRService。
2. ASRService。
3. LLMService。
4. PlanningService。
5. CalendarSyncService。
6. NotificationService。
7. FileStorageService。
8. PermissionService。

Data Layer：

1. SwiftData 本地数据库。
2. 文件存储。
3. Repository。
4. Migration。
5. CloudKit 同步，Beta 阶段再加。

Integration Layer：

1. Apple Vision Adapter。
2. Apple Speech Adapter。
3. OpenAI Adapter。
4. EventKit Adapter。
5. Google Calendar Adapter，后续。
6. Microsoft Graph Adapter，后续。

Extension Layer：

1. Share Extension。
2. App Intents。
3. Widgets。
4. Shortcuts。

### 6.2 关键协议

```swift
protocol OCRService {
    func recognizeText(from image: ImageInput) async throws -> OCRResult
}

protocol ASRService {
    func transcribe(audio: AudioInput) async throws -> TranscriptResult
}

protocol LLMService {
    func extractCandidates(from context: ExtractionContext) async throws -> ExtractionResult
    func planEvent(from context: PlanningContext) async throws -> PlanningResult
}

protocol CalendarSyncService {
    func createEvent(_ event: CalendarEvent) async throws -> ExternalCalendarEventID
    func updateEvent(_ event: CalendarEvent) async throws
    func deleteEvent(_ eventID: ExternalCalendarEventID) async throws
    func fetchEvents(range: DateRange) async throws -> [ExternalCalendarEvent]
}

protocol FileStorageService {
    func saveRawInputFile(_ data: Data, suggestedName: String, type: RawInputType) async throws -> StoredFile
    func loadFile(_ reference: StoredFileReference) async throws -> Data
    func deleteFile(_ reference: StoredFileReference) async throws
}
```

### 6.3 并发模型

1. UI 使用 MainActor。
2. OCR、ASR、LLM 调用使用 async/await。
3. 预处理和提取任务通过 Job 状态持久化，避免 App 退出后状态丢失。
4. 网络 LLM 调用必须支持取消、重试、超时和错误分类。
5. 所有后台任务都要写入 LLMTrace 或 ProcessingTrace。

## 7. 数据模型

### 7.1 RawInput

用途：保存所有原始输入，是可追溯链路的起点。

核心字段：

1. id。
2. inputType：image、audio、text、file、url。
3. source：appUpload、shareExtension、clipboard、voiceRecording、shortcut。
4. createdAt。
5. originalFileURI。
6. thumbnailURI。
7. rawText。
8. status。
9. contentHash。
10. metadata。
11. deletedAt。

验收要求：

1. 每次输入都必须先创建 RawInput。
2. 文件型输入不能直接塞进数据库。
3. 用户删除 RawInput 时，相关候选事件必须显示来源已删除或同步删除，具体策略在设置中明确。
4. contentHash 用于去重。

### 7.2 PreprocessResult

用途：保存 OCR、ASR、文本清洗结果。

核心字段：

1. id。
2. rawInputID。
3. preprocessType：ocr、asr、textCleanup、languageDetection。
4. text。
5. confidence。
6. blocks 或 segments。
7. language。
8. createdAt。
9. engineName。
10. engineVersion。

验收要求：

1. 图片必须保留 OCR blocks。
2. 音频必须保留 transcript segments。
3. 预处理失败不删除 RawInput。

### 7.3 CandidateEvent

用途：保存 LLM 提取出的待审核日程草稿。

核心字段：

1. id。
2. rawInputID。
3. extractionID。
4. title。
5. startAt。
6. endAt。
7. timezone。
8. isAllDay。
9. timeStatus：confirmed、inferred、missing、needsConfirmation。
10. locationType：physical、online、phone、tbd、notApplicable。
11. locationName。
12. locationAddress。
13. locationStatus。
14. priority。
15. urgencyReason。
16. notes。
17. overallConfidence。
18. status。
19. sourceSummary。
20. questionsForUser。
21. lockedFields。
22. createdAt。
23. updatedAt。

验收要求：

1. 一条 RawInput 可以产生多个 CandidateEvent。
2. 缺少明确时间时不能进入正式日程。
3. 地点字段必须有类型，不能强迫用户填写假地址。
4. 用户编辑过的字段必须记录为 user_locked。

### 7.4 CustomField

用途：保存动态字段，不把动态信息变成数据库新列。

核心字段：

1. id。
2. ownerType：candidateEvent、calendarEvent。
3. ownerID。
4. key。
5. label。
6. type：string、number、boolean、datetime、url、person、location、enum、file。
7. value。
8. source：llm、user、rule、integration。
9. confidence。
10. isUserModified。
11. lockStatus。
12. sourceText。
13. createdAt。
14. updatedAt。

验收要求：

1. 用户可新增、修改、删除动态字段。
2. 类型切换时要处理值转换失败。
3. URL、日期、数字要做基础校验。

### 7.5 CalendarEvent

用途：内置日程表的主数据源。

核心字段：

1. id。
2. title。
3. startAt。
4. endAt。
5. timezone。
6. isAllDay。
7. locationType。
8. locationName。
9. locationAddress。
10. notes。
11. priority。
12. sourceCandidateID。
13. sourceRawInputIDs。
14. reminders。
15. status。
16. createdAt。
17. updatedAt。
18. userModifiedFields。

验收要求：

1. 正式日程可以追溯 CandidateEvent 和 RawInput。
2. 提交后复制 CandidateEvent 的动态字段到 CalendarEvent。
3. 后续重新规划不能覆盖 userModifiedFields，除非用户明确允许。

### 7.6 CalendarSyncRecord

用途：记录内置日程和外部日历的同步关系。

核心字段：

1. id。
2. calendarEventID。
3. provider：appleEventKit、googleCalendar、microsoftGraph。
4. externalID。
5. externalCalendarID。
6. lastSyncedAt。
7. syncStatus。
8. lastError。

验收要求：

1. 创建、更新、删除外部事件都必须通过 SyncRecord 找到对应关系。
2. 同步失败不能影响内置日程可用性。

### 7.7 LLMTrace

用途：记录模型调用和调试信息。

核心字段：

1. id。
2. rawInputID。
3. candidateEventID。
4. taskType：extraction、planning、repair。
5. inputHash。
6. promptVersion。
7. schemaVersion。
8. modelProvider。
9. modelName。
10. rawResponse。
11. parsedResponse。
12. latencyMs。
13. tokenUsage。
14. costEstimate。
15. error。
16. createdAt。

验收要求：

1. 隐私模式下不保存敏感 rawResponse，或只保存本地加密版本。
2. Prompt 和 Schema 版本必须入库。

## 8. LLM 设计

### 8.1 两阶段模型职责

第一次 LLM：结构化提取。

输入：

1. RawInput 元数据。
2. OCR 或 ASR 文本。
3. 输入创建时间。
4. 用户时区。
5. Schema version。

输出：

1. 0 个、1 个或多个 CandidateEvent。
2. 字段值、置信度、来源文本。
3. 缺失字段。
4. 给用户的问题。
5. 动态字段。

第二次 LLM：规划建议。

输入：

1. 用户审核后的 CandidateEvent。
2. 已有日程。
3. 用户偏好。
4. 锁定字段。
5. 默认提醒和默认时长。
6. 冲突规则。

输出：

1. recommendedEvent。
2. conflicts。
3. userDecisionsRequired。
4. notes。

### 8.2 LLM 约束

1. 不确定字段必须返回 missing 或 needs_confirmation。
2. 不允许编造时间、地点、人物。
3. 每个关键字段都必须带 confidence。
4. 每个关键字段尽量带 source_text。
5. 动态字段必须带 type 和 source_text。
6. 用户锁定字段不能被规划阶段覆盖。
7. 结构化输出必须通过 JSON Schema 校验。
8. Schema 校验失败时进入 repair 流程或失败状态，不直接使用。

### 8.3 Prompt 版本管理

每次 Prompt 变更记录：

1. prompt_version。
2. schema_version。
3. model_provider。
4. model_name。
5. changed_reason。
6. test_cases。
7. known_failure_cases。

建议目录：

```text
prompts/
  extraction/
    v1.md
  planning/
    v1.md
  repair/
    v1.md
```

### 8.4 评测集

第一批评测样例至少包含：

1. 中文聊天截图：明确时间地点。
2. 中文聊天截图：只有相对时间。
3. 英文邮件：会议邀请。
4. 活动海报：多行文字和地点。
5. 票据或订单：含订单号和截止时间。
6. 无日程文本：应输出 0 个候选。
7. 多个日程文本：应输出多个候选。
8. 缺少地点文本：地点为 tbd 或 not_applicable。
9. 线上会议链接：地点为 online。
10. 模糊时间：needs_confirmation。

## 9. 页面设计计划

### 9.1 首页

首屏目标：让用户知道今天有什么、还有多少待审核、可以快速捕获新输入。

模块：

1. 今日安排列表。
2. 待审核数量入口。
3. 快速输入按钮。
4. 最近捕获。
5. 冲突提醒。
6. 今日高优先级事项。

MVP 验收：

1. 能看到今日正式日程。
2. 能看到待审核数量。
3. 能一键进入快速输入。

### 9.2 快速输入页

入口：

1. 输入文本。
2. 粘贴剪贴板。
3. 选截图。
4. 拍照，后置。
5. 录音，后置。
6. 导入文件，后置。

MVP 验收：

1. 输入文本后创建 RawInput。
2. 选择图片后创建 RawInput 并进入 OCR。
3. 处理失败能重试。

### 9.3 Inbox 页

显示：

1. 原始输入类型。
2. 来源。
3. 创建时间。
4. 处理状态。
5. 缩略图或文本摘要。
6. 失败原因。
7. 重试按钮。

MVP 验收：

1. 所有文本和图片输入都出现在 Inbox。
2. 点击可查看原始内容和预处理文本。
3. 已生成候选日程的输入能跳转到候选列表。

### 9.4 待审核页

显示：

1. 候选标题。
2. 时间。
3. 地点。
4. 来源类型。
5. 置信度。
6. 缺失字段提示。
7. 冲突提示。
8. 忽略按钮。
9. 提交按钮。

MVP 验收：

1. CandidateEvent 能按状态展示。
2. 缺时间或地点状态时不能直接提交。
3. 用户能忽略错误候选。

### 9.5 审核详情页

核心组件：

1. 原始输入预览。
2. OCR 或转写文本。
3. 固定字段编辑器。
4. 动态字段编辑器。
5. LLM 提取依据。
6. 问题提示区。
7. 提交进入规划。

MVP 验收：

1. 修改字段后保存。
2. 用户修改字段标记 user_locked。
3. 动态字段可新增、删除、重命名。
4. 提交前运行必填校验。

### 9.6 日程表页

MVP 视图：

1. 今日。
2. 列表。
3. 搜索。
4. 状态筛选。

后续视图：

1. 周视图。
2. 月视图。
3. 来源筛选。

MVP 验收：

1. 提交后的 CalendarEvent 能展示。
2. 能进入详情编辑。
3. 删除正式日程不会删除 RawInput，除非用户选择级联删除。

### 9.7 设置页

MVP 设置：

1. 默认提醒时间。
2. 默认日程时长。
3. 工作时间。
4. LLM 服务设置。
5. 隐私模式。
6. 数据删除。

后续设置：

1. 日历同步目标。
2. 常用地点。
3. 常用联系人。
4. 数据导出。
5. CloudKit 同步。

## 10. 阶段路线图

### Phase 0：技术验证

建议周期：1 到 2 周。

目标：

证明“输入 -> 结构化候选 -> 审核 -> 内置日程”核心链路可行。

任务：

1. 创建 SwiftUI 项目骨架。
2. 建立 Tab 导航：Inbox、Review、Calendar、Settings。
3. 建立 SwiftData 配置。
4. 定义 RawInput、CandidateEvent、CalendarEvent、CustomField。
5. 实现文本输入。
6. 实现 MockLLMService。
7. 展示待审核卡片。
8. 实现审核详情基础编辑。
9. 提交生成 CalendarEvent。

验收标准：

1. 用户输入“明天下午三点在国贸 B 座见张总，带合同”。
2. 系统生成一条候选日程。
3. 用户可修改标题、时间、地点、动态字段。
4. 用户提交后，日程出现在内置日程表。

### Phase 1：MVP

建议周期：3 到 6 周。

目标：

支持文本和截图两类高频输入，形成完整待审核工作流。

任务：

1. 完成 Inbox 列表和详情。
2. 实现 PhotosUI 图片选择。
3. 实现图片文件保存和缩略图。
4. 实现 Vision OCR。
5. OCR 文本接入提取流程。
6. 实现字段置信度展示。
7. 实现动态字段编辑器。
8. 实现本地通知提醒。
9. 实现基础搜索和筛选。
10. 实现隐私设置和数据删除。
11. 增加基础单元测试。

验收标准：

1. 用户选择聊天截图。
2. 系统 OCR 后提取候选日程。
3. 用户能查看原图、OCR 文本、字段依据。
4. 用户能编辑固定字段和动态字段。
5. 提交后生成内置日程和本地提醒。

### Phase 2：系统集成

建议周期：4 到 8 周。

目标：

让 App 能从系统分享、音频、系统日历进入更完整的使用场景。

任务：

1. 实现 Share Extension。
2. 配置 App Group 文件交换。
3. 主 App 导入 Share Extension 输入。
4. 实现 EventKit 权限请求。
5. 实现 Apple Calendar 创建事件。
6. 保存 CalendarSyncRecord。
7. 支持同步更新和删除。
8. 实现音频导入。
9. 实现 ASRService 协议。
10. 接入 Apple Speech 或云端 ASR。
11. 实现冲突检测。
12. 实现重新规划。

验收标准：

1. 用户可从相册或其他 App 分享图片或文本到本 App。
2. 用户可把正式日程同步到系统日历。
3. 同步失败可重试，内置日程不丢失。
4. 音频转写后可生成候选日程。

### Phase 3：智能规划增强

建议周期：6 到 10 周。

目标：

把“可用”提升为“智能好用”，但仍保持用户确认机制。

任务：

1. 接入真实 LLM Provider。
2. 增加 JSON Schema 校验。
3. 增加 repair prompt。
4. 实现已有日程上下文输入。
5. 实现 PlanningService。
6. 支持冲突建议。
7. 支持默认时长和工作时间偏好。
8. 支持提醒智能建议。
9. 支持批量审核。
10. 支持“不是日程”的负样本标记。
11. 建立 evals 回归集。

验收标准：

1. 遇到日程冲突时能提示冲突并给出建议。
2. 不会静默改动用户锁定字段。
3. Prompt 更新后可用评测集回归。

### Phase 4：产品化和多端准备

建议周期：8 周以上。

目标：

从个人 MVP 走向可公开测试版本。

任务：

1. CloudKit 多设备同步。
2. macOS 版本。
3. 隐私中心。
4. 数据导出。
5. LLM 成本统计。
6. 崩溃和错误监控。
7. App Store 隐私材料准备。
8. 后端可行性评估。
9. Google Calendar 和 Outlook 方案设计。
10. 订阅或用量计费方案。

验收标准：

1. 用户可在多个 Apple 设备访问内置日程。
2. 用户可清晰查看和删除敏感数据。
3. 产品可进入公开 TestFlight。

## 11. 任务拆分

### Task 1：创建 iOS 项目骨架

目标：

建立可持续扩展的 SwiftUI 项目基础。

交付物：

1. SwiftUI App。
2. 四个 Tab：Inbox、Review、Calendar、Settings。
3. SwiftData 容器。
4. 基础 Models。
5. Repository 初版。

验收标准：

1. App 可运行。
2. 四个 Tab 可切换。
3. SwiftData 可写入和读取示例数据。

### Task 2：实现文本输入到待审核

目标：

打通第一条完整业务链路。

交付物：

1. 文本输入页。
2. RawInput 创建。
3. MockLLMService。
4. CandidateEvent 创建。
5. 待审核列表。
6. 审核详情编辑。
7. 提交生成 CalendarEvent。

验收标准：

1. 文本输入后能生成候选日程。
2. 用户编辑字段后能保存。
3. 提交后能在 Calendar 页看到正式日程。

### Task 3：实现动态字段编辑器

目标：

支持 LLM 根据输入内容扩展字段。

交付物：

1. DynamicFieldEditor。
2. 类型选择器。
3. 字符串、数字、日期、URL、布尔值编辑。
4. 字段删除。
5. 字段重命名。
6. 字段校验。

验收标准：

1. 用户可新增“需携带材料：合同”。
2. 用户可新增“会议链接：URL”。
3. 错误 URL 有提示。
4. 字段随 CandidateEvent 保存。

### Task 4：实现图片选择与 OCR

目标：

支持截图输入。

交付物：

1. PhotosUI 图片选择。
2. 图片文件保存。
3. 缩略图生成。
4. Vision OCR。
5. OCRResult 持久化。
6. OCR 文本进入 LLM 提取流程。

验收标准：

1. 选择截图后 RawInput 出现在 Inbox。
2. OCR 完成后能查看识别文本。
3. OCR 文本能生成候选日程。

### Task 5：实现 LLM Provider 抽象

目标：

让模型服务可替换、可测试、可追踪。

交付物：

1. LLMService protocol。
2. MockLLMService。
3. OpenAILLMService 占位或真实调用。
4. ModelConfig。
5. PromptTemplate。
6. JSON Schema 校验。
7. LLMTrace。

验收标准：

1. App 可在 Mock 和真实 Provider 之间切换。
2. 提取结果不符合 Schema 时不会进入待审核。
3. 调用日志可追踪。

### Task 6：实现审核后规划

目标：

让审核后的候选日程进入正式日程前经过规则校验。

交付物：

1. PlanningService。
2. RequiredFieldValidator。
3. ReminderGenerator。
4. CandidateEvent -> CalendarEvent 转换。
5. 用户锁定字段保护。

验收标准：

1. 缺少时间不能提交。
2. 地点为 tbd 或 not_applicable 可提交，但状态清楚。
3. 默认提醒按用户设置生成。

### Task 7：实现 EventKit 同步

目标：

把内置日程可选同步到 Apple Calendar。

交付物：

1. EventKit 权限请求。
2. 日历选择。
3. EventKitCalendarSyncService。
4. CalendarSyncRecord。
5. 创建、更新、删除同步。
6. 同步失败重试。

验收标准：

1. 用户授权后可创建系统日历事件。
2. 外部事件 ID 被保存。
3. 删除或修改内置日程时可同步外部日历。

### Task 8：实现 Share Extension

目标：

支持从其他 App 分享输入。

交付物：

1. Share Extension target。
2. 接收文本、图片、文件。
3. App Group 容器。
4. 主 App 导入分享队列。
5. 导入后创建 RawInput。

验收标准：

1. 从相册分享图片到 App 后，Inbox 出现 RawInput。
2. 从备忘录分享文本到 App 后，能进入提取流程。

### Task 9：实现音频导入与转写

目标：

支持录音或音频文件中的日程提取。

交付物：

1. 音频文件导入。
2. App 内录音，后置。
3. ASRService。
4. TranscriptResult。
5. 转写文本进入 LLM 提取流程。

验收标准：

1. 导入音频后生成 transcript。
2. transcript 可生成候选日程。
3. 用户能查看原始音频和转写文本。

### Task 10：实现重新规划

目标：

让正式日程可根据新上下文更新建议。

交付物：

1. 日程详情页重新规划按钮。
2. PlanningContext 生成。
3. PlanningResult 展示。
4. 用户确认后更新 CalendarEvent。
5. 可选同步更新系统日历。

验收标准：

1. 用户锁定字段默认不被覆盖。
2. 冲突建议必须由用户确认。
3. 更新后有规划历史。

## 12. 确定性规则引擎

LLM 输出不能直接作为事实使用。正式提交前规则引擎必须检查：

1. title 不能为空。
2. startAt 必须明确，除非是待办模式，MVP 暂不支持无时间待办。
3. endAt 为空时按默认时长生成。
4. timezone 必须存在。
5. locationType 必须存在。
6. physical 类型如果没有地址也可提交，但要保留地点名。
7. online 类型应优先识别 URL。
8. reminders 的 offset 不能为负到不合理范围。
9. 用户锁定字段不能被规划覆盖。
10. 重复事件创建前进行相似度检查。

## 13. 隐私与安全计划

### 13.1 权限请求

按需请求：

1. 相册权限：用户选择截图时。
2. 麦克风权限：App 内录音时。
3. 语音识别权限：启用本地 Speech 时。
4. 日历权限：启用 EventKit 同步时。
5. 通知权限：创建本地提醒时。
6. 定位权限：未来做通勤提醒时。

### 13.2 本地优先策略

默认：

1. 原始截图本地保存。
2. 原始音频本地保存。
3. OCR 本地处理。
4. LLM 云端处理默认关闭或首次清晰提示。
5. 隐私模式下禁止上传原始图片和音频，只上传用户确认的文本或完全不上传。

### 13.3 密钥策略

MVP 个人自用：

1. API Key 可存入 Keychain。
2. 设置页允许用户清除 API Key。

正式产品：

1. iOS 客户端不硬编码服务商 API Key。
2. 通过后端代理调用 LLM。
3. 后端做鉴权、限流、成本控制和审计。

### 13.4 用户数据控制

必须提供：

1. 删除单条 RawInput。
2. 删除所有原始图片和录音。
3. 删除 LLMTrace。
4. 删除所有本地数据。
5. 导出数据。
6. 关闭云端处理。
7. 关闭云同步。
8. 查看将发送给 LLM 的内容。

## 14. 测试计划

### 14.1 单元测试

覆盖：

1. 日期解析基准时间。
2. CandidateEvent 必填校验。
3. CustomField 类型转换。
4. CandidateEvent -> CalendarEvent 转换。
5. ReminderGenerator。
6. DuplicateDetector。
7. LLM JSON Schema 校验。
8. Prompt repair 流程。

### 14.2 集成测试

覆盖：

1. 文本输入完整链路。
2. 图片 OCR 完整链路。
3. 提交审核到日程表。
4. 本地通知创建。
5. EventKit 同步，使用 mock adapter。
6. Share Extension 导入，使用测试容器。

### 14.3 UI 测试

覆盖：

1. 四个 Tab 导航。
2. 快速输入文本。
3. 待审核详情编辑。
4. 动态字段新增删除。
5. 日程详情编辑。
6. 设置项修改。

### 14.4 LLM 评测

指标：

1. 是否正确识别为日程。
2. 标题准确率。
3. 时间准确率。
4. 地点准确率。
5. 人物识别准确率。
6. 动态字段召回率。
7. 无日程样本误报率。
8. Schema 通过率。
9. 平均延迟。
10. 单次成本。

## 15. 风险清单

### 15.1 iOS 平台限制

风险：

不能后台自动读取所有截图或第三方 App 聊天记录。

处理：

产品入口明确为分享、选择、导入、粘贴、快捷指令，不承诺自动读取。

### 15.2 LLM 幻觉

风险：

模型编造时间、地点、人物。

处理：

1. 必须带 source_text。
2. 无依据字段标记 missing 或 inferred。
3. 低置信度进入人工确认。
4. 提交前规则校验。

### 15.3 时间歧义

风险：

“明天”“周五”“月底前”等表达解析错误。

处理：

1. 保存输入创建时间。
2. 保存用户时区。
3. 相对日期基于输入时间解析。
4. 模糊时间不能直接入正式日程。

### 15.4 重复创建

风险：

同一截图或文本多次导入导致重复日程。

处理：

1. RawInput hash 去重。
2. CandidateEvent 相似度去重。
3. CalendarSyncRecord 保存外部 ID。
4. 同步前检查相似事件。

### 15.5 成本和延迟

风险：

云端模型调用慢且贵。

处理：

1. 本地 OCR 优先。
2. 简单任务用小模型。
3. 复杂规划才用强模型。
4. 结果缓存。
5. 用户可选省钱模式和高精度模式。

### 15.6 隐私合规

风险：

截图、录音、日程、地点都属于敏感数据。

处理：

1. 默认本地保存。
2. 云端上传前明确告知。
3. 提供删除、导出、关闭云端处理。
4. 日志默认脱敏。
5. 上架前准备隐私说明和权限用途文案。

## 16. Git 和协作规范

### 16.1 分支

建议：

1. main：稳定分支。
2. feature/xxx：功能分支。
3. fix/xxx：修复分支。
4. chore/xxx：工程维护。
5. experiment/xxx：实验功能。

### 16.2 Commit

使用 Conventional Commits：

```text
feat: add inbox raw input model
fix: prevent duplicate calendar sync
docs: add llm extraction schema
test: add ocr fixture tests
refactor: extract calendar sync service protocol
chore: setup github actions
```

### 16.3 PR 检查清单

每个 PR 至少检查：

1. 是否有单元测试。
2. 是否影响数据模型。
3. 是否需要数据库迁移。
4. 是否修改 Prompt。
5. 是否修改 JSON Schema。
6. 是否影响隐私权限。
7. 是否影响 App Store 审核材料。
8. 是否需要更新 README 或 docs。
9. 是否有截图或录屏。

## 17. 第一批具体开发顺序

建议从以下顺序开始，不要先做 Share Extension、EventKit 或真实 LLM：

1. 建立仓库文档和目录。
2. 创建 iOS SwiftUI 项目。
3. 创建 Tab 导航。
4. 建立 SwiftData Models。
5. 实现 RawInputRepository。
6. 实现文本输入。
7. 实现 MockLLMService。
8. 实现 CandidateEventRepository。
9. 实现待审核列表。
10. 实现审核详情页。
11. 实现 CustomField 编辑器。
12. 实现 PlanningService 基础规则。
13. 实现 CalendarEventRepository。
14. 实现内置日程列表。
15. 增加本地通知。
16. 再接图片选择和 Vision OCR。
17. 再接真实 LLM Provider。

## 18. 近期可交付清单

第一个可交付版本应包含：

1. `README.md`：项目介绍、MVP 范围、运行方式。
2. `docs/product/PRD.md`：产品需求。
3. `docs/architecture/architecture-overview.md`：架构说明。
4. `docs/architecture/data-model.md`：数据模型。
5. `docs/architecture/llm-pipeline.md`：LLM 流程。
6. `docs/architecture/privacy-security.md`：隐私安全。
7. `schemas/extraction-result.schema.json`。
8. `schemas/candidate-event.schema.json`。
9. `schemas/planning-result.schema.json`。
10. `prompts/extraction/v1.md`。
11. iOS 项目骨架。

## 19. Definition of Done

一个功能完成必须满足：

1. 用户路径跑通。
2. 错误状态可见。
3. 失败可重试或可恢复。
4. 数据能持久化。
5. 敏感数据处理符合隐私策略。
6. 有必要的单元测试或 UI 测试。
7. 文档、Schema、Prompt 同步更新。
8. 不破坏已有 RawInput 到 CalendarEvent 的追溯链路。

## 20. 下一步建议

下一步最适合让 Codex 执行的任务是：

```text
创建项目文档骨架和 iOS MVP 代码骨架：
1. 建立 docs、schemas、prompts、apps/ios 目录。
2. 补充 README.md。
3. 创建 SwiftUI 项目或 Swift Package 骨架。
4. 实现 Inbox / Review / Calendar / Settings 四个 Tab。
5. 定义 RawInput、CandidateEvent、CalendarEvent、CustomField 基础模型。
6. 实现文本输入到 Mock 候选日程的闭环。
```

如果先不创建 Xcode 项目，也可以先完成文档和 JSON Schema，这能降低后续实现时的数据模型返工。
