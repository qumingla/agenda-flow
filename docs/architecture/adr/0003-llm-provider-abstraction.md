# ADR 0003: LLM Provider Abstraction

## Status

Accepted.

## Context

模型服务、成本、延迟和隐私策略会变化。

## Decision

业务层只依赖 `LLMService` 协议。Beta 使用 `MockLLMService`，后续替换为 OpenAI 或其他 provider。

## Consequences

- 便于测试。
- Prompt、Schema 和 Provider 可以独立版本化。
