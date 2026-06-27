# ADR 0003: LLM Provider Abstraction

## Status

Accepted.

## Context

模型服务、成本、延迟和隐私策略会变化。

## Decision

业务层只依赖 `LLMService` 协议。Beta 默认使用 `MockLLMService`，也可以通过 `LLMServiceFactory` 按用户设置切换到 OpenAI-compatible Provider。

Provider 配置包括：

- provider preset。
- Base URL。
- model name。
- API Key，存储于 Keychain。
- JSON Mode。
- 是否保存原始响应。
- 云端失败是否回退本地规则。

## Consequences

- 便于测试。
- Prompt、Schema 和 Provider 可以独立版本化。
- 同一套业务流程可以接入 OpenAI、DeepSeek、通义千问、Kimi、智谱、OpenRouter 或自定义兼容接口。
