# Architecture Overview

## 分层

App Layer：

- SwiftUI Views。
- NavigationStack 和 TabView。
- AppStorage 设置。

Domain/Data Layer：

- SwiftData `@Model`。
- RawInputModel。
- PreprocessResultModel。
- CandidateEventModel。
- CalendarEventModel。
- CustomFieldModel。
- LLMTraceModel。

Service Layer：

- LocalFileStorageService。
- AppleVisionOCRService。
- OpenAICompatibleOCRService，可选云端视觉模型 OCR。
- MockLLMService。
- OpenAICompatibleLLMService，默认用于云端结构化规整并支持本地回退。
- BetaExtractionPipeline。
- BetaPlanningService。
- NotificationScheduler。

Integration Layer：

- Vision 已接入。
- EventKit、Share Extension、ASR、更多真实模型 Provider 后续通过协议接入。

## Beta 架构原则

1. Inbox 是所有输入的第一站。
2. 模型输出只创建候选事件。
3. 用户确认后才能创建正式日程。
4. 自定义字段独立建模，不扩展固定列。
5. 通知调度使用 Sendable 快照，避免 SwiftData model 跨 actor 发送。
6. Liquid Glass 使用 `glassEffect`，并保留旧系统回退。
