# User Flows

## 文本到日程

```text
捕获页
  -> 输入或粘贴文本
  -> 创建 RawInput
  -> 云端 LLM 或 MockLLMService 提取 CandidateEvent
  -> 待审核列表
  -> 审核详情编辑
  -> 规则校验
  -> CalendarEvent
  -> 日程页展示
```

## 图片到日程

```text
捕获页
  -> 选择图片
  -> 保存原图和缩略图
  -> Apple Vision 或云端视觉模型 OCR
  -> PreprocessResult
  -> 云端 LLM 或 MockLLMService 提取 CandidateEvent
  -> 待审核
```

## 提交流程

```text
CandidateEvent
  -> 检查明确 startDate
  -> 检查 locationType
  -> 默认 endDate
  -> 默认 reminders
  -> 复制 CustomField
  -> CalendarEvent
  -> 可选本地通知
```
