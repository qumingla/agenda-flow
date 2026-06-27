# ADR 0001: iOS First

## Status

Accepted.

## Context

产品需要低摩擦接收截图、文本、通知和日历数据。iOS 提供 PhotosUI、Vision、SwiftData、UserNotifications、EventKit、Share Extension 和 App Intents。

## Decision

先实现 iOS beta。核心模型保持平台无关，后续再扩展 macOS、Web 和 Android。

## Consequences

- 第一阶段可以快速验证用户流程。
- Android/Web 后续需要重新实现平台入口和本地存储。
