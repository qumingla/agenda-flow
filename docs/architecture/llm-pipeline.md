# LLM Pipeline

## Beta 实现

Beta 版默认使用 `MockLLMService` 本地规则提取：

- 相对日期：今天、明天、后天、周几。
- 时间：上午、下午、晚上、点、冒号时间。
- 地点：在、地点、地址、URL、电话、线上会议关键词。
- 优先级：紧急、提醒、别忘、截止。
- 动态字段：会议链接、需携带材料、合同主题。

同时已经接入 OpenAI-compatible 云端 Provider：

- OpenAI。
- DeepSeek。
- 通义千问 compatible mode。
- Kimi / Moonshot。
- 智谱 GLM。
- OpenRouter。
- 自定义 Base URL。

设置页支持：

1. 关闭或开启云端 LLM。
2. 选择 Provider。
3. 手动填写 Base URL 和模型名。
4. 保存 API Key 到 Keychain。
5. 调用 `GET /models` 测试连接并获取模型列表。
6. 从模型列表中手动选择后续使用的模型。
7. 云端失败时可回退本地规则。

## 目标架构

真实 LLM Provider 应实现：

```swift
protocol LLMService {
    func extractCandidates(from text: String, referenceDate: Date) async throws -> LLMExtractionResult
}
```

后续可扩展：

- AnthropicLLMService。
- LocalLLMService。
- RepairLLMService。

## 约束

1. 不确定字段必须 `missing` 或 `needsConfirmation`。
2. 不编造时间、地点、人物。
3. 关键字段必须带置信度。
4. 用户锁定字段不能被规划覆盖。
5. JSON Schema 校验失败不得进入正式日程。
6. 默认不保存云端原始响应，只保存响应 hash；用户可在设置中显式打开原始响应保存。
