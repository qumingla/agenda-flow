# Data Model

## RawInputModel

保存原始输入。

关键字段：

- `id`
- `inputTypeRaw`
- `sourceRaw`
- `createdAt`
- `originalFilePath`
- `thumbnailPath`
- `originalText`
- `rawText`
- `statusRaw`
- `contentHash`
- `failureReason`

## PreprocessResultModel

保存 OCR 或后续 ASR 结果。

关键字段：

- `rawInput`
- `preprocessType`
- `text`
- `confidence`
- `blocksJSON`
- `engineName`
- `engineVersion`

## CandidateEventModel

保存待审核日程草稿。

关键字段：

- `rawInput`
- `titleValue`
- `startDate`
- `endDate`
- `timeStatusRaw`
- `locationTypeRaw`
- `locationName`
- `priorityRaw`
- `overallConfidence`
- `statusRaw`
- `lockedFieldsBlob`

## CalendarEventModel

保存内置日程表正式事件。

关键字段：

- `title`
- `startDate`
- `endDate`
- `locationTypeRaw`
- `locationName`
- `notes`
- `priorityRaw`
- `sourceCandidateID`
- `sourceRawInputIDsBlob`
- `remindersBlob`
- `statusRaw`

## CustomFieldModel

保存动态字段，避免数据库为每种新字段迁移。

关键字段：

- `ownerTypeRaw`
- `ownerID`
- `key`
- `label`
- `typeRaw`
- `value`
- `sourceRaw`
- `confidence`
- `isUserModified`
- `lockStatusRaw`
- `sourceText`

## LLMTraceModel

保存模型调用和调试信息。

当前 beta 使用本地 MockLLMService，也会记录 trace。
