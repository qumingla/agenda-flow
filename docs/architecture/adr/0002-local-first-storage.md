# ADR 0002: Local First Storage

## Status

Accepted.

## Context

应用处理截图、聊天文本、地点和日程，数据敏感。

## Decision

Beta 使用 SwiftData + App 沙盒文件系统。原始图片不写入数据库，只保存路径。

## Consequences

- 隐私风险较低。
- 后续 CloudKit 或自建后端需要同步策略和迁移计划。
