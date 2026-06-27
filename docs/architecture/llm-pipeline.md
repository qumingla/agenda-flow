# LLM Pipeline

## Beta 实现

Beta 版没有调用云端 LLM。`MockLLMService` 使用本地规则提取：

- 相对日期：今天、明天、后天、周几。
- 时间：上午、下午、晚上、点、冒号时间。
- 地点：在、地点、地址、URL、电话、线上会议关键词。
- 优先级：紧急、提醒、别忘、截止。
- 动态字段：会议链接、需携带材料、合同主题。

## 目标架构

真实 LLM Provider 应实现：

```swift
protocol LLMService {
    func extractCandidates(from text: String, referenceDate: Date) async throws -> [CandidateDraft]
}
```

后续可扩展：

- OpenAILLMService。
- AnthropicLLMService。
- LocalLLMService。
- RepairLLMService。

## 约束

1. 不确定字段必须 `missing` 或 `needsConfirmation`。
2. 不编造时间、地点、人物。
3. 关键字段必须带置信度。
4. 用户锁定字段不能被规划覆盖。
5. JSON Schema 校验失败不得进入正式日程。
