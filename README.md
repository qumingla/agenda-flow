# Agenda Flow

Agenda Flow 是一个 iOS 优先的多模态智能日程收集箱。Beta 版把文本、剪贴板内容和截图先放入 Inbox，经 OCR 和 LLM 提取生成待审核日程草稿，用户确认后再写入内置日程表。

## Beta 能力

- 文本输入和剪贴板解析。
- 相册图片导入。
- OCR 默认使用 Apple Vision 本地识别，也可手动切换到 OpenAI-compatible 云端视觉模型。
- LLM 默认使用云端 Provider 做结构化规整；未配置 Key 或云端失败时可回退本地 MockLLMService。
- OpenAI-compatible 云端 Provider，可选 OpenAI、DeepSeek、通义千问、Kimi、智谱、OpenRouter 或自定义 Base URL。
- 设置页保存 API Key 到 Keychain，OCR 和 LLM 都支持测试 `/models` 并手动选择模型。
- 待审核列表和审核详情编辑。
- 固定字段：标题、时间、地点、优先级、备注、提醒。
- 动态字段：新增、修改、删除、类型切换。
- 审核后生成内置日程。
- 本地通知提醒。
- iOS 26 Liquid Glass 风格，低版本使用系统 material 回退。

## 暂未实现

- Share Extension。
- EventKit 系统日历同步。
- 音频导入和 ASR。
- CloudKit 多设备同步。
- 自动读取聊天 App 或后台扫描截图。

## 目录

```text
apps/ios/SmartSchedule.xcodeproj
apps/ios/SmartSchedule/
docs/
schemas/
prompts/
evals/
DETAILED_PLAN.md
```

## 构建

当前本机验证命令：

```bash
xcodebuild -project apps/ios/SmartSchedule.xcodeproj \
  -target SmartSchedule \
  -sdk iphoneos26.5 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

验证结果：通过，`BUILD SUCCEEDED`。

如需通过 Xcode scheme 构建，需要本机 Xcode 能解析完整 iOS platform destination：

```bash
xcodebuild -project apps/ios/SmartSchedule.xcodeproj \
  -scheme SmartSchedule \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 使用路径

1. 打开 App，进入“捕获”。
2. 默认使用本地 OCR + 云端 LLM 规整；在“设置”里可分别配置 OCR 方式、LLM Provider、API Key、模型获取和手动模型选择。
3. 输入文本或从剪贴板粘贴日程信息，也可以选择截图。
4. App 创建 RawInput，并按设置进行 OCR 或文本提取。
5. 进入“审核”，修改候选日程字段和动态字段。
6. 点击“提交到日程表”。
7. 在“日程”中查看正式日程。

## 设计原则

- 用户确认优先于模型判断。
- LLM 只生成候选和建议，不直接写入最终日程。
- 原始输入、候选日程、正式日程之间保持可追溯。
- 隐私默认本地 OCR 优先；任何云端 OCR 或 LLM 都由用户在设置中配置和控制。
- 外部能力通过协议和 Adapter 接入。
