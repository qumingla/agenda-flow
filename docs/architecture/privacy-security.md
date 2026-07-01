# Privacy and Security

## 默认策略

Beta 版默认采用本地 OCR、云端 LLM 规整：

- 文本留在本地 SwiftData。
- 图片保存在 App 沙盒文件系统。
- OCR 默认使用 Apple Vision 本地能力。
- LLM 默认可使用用户配置的 OpenAI-compatible Provider 处理 OCR 文本或用户输入文本。
- 未配置 API Key、云端请求失败或用户开启“强制全本地处理”时，会回退到本地 MockLLMService。

用户在设置中把 OCR 切换为“云端视觉模型”后，原始图片会发送到所选 OpenAI-compatible 视觉模型进行文字识别。保持默认本地 OCR 时，原始图片不会上传；但 OCR 文本或手动文本可能会发送给已启用的云端 LLM 做结构化规整。

## 权限

当前 Info.plist 声明：

- `NSPhotoLibraryUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`

麦克风和语音识别是后续音频能力预留。Beta 当前不会主动请求这两个权限。

## 数据控制

设置页提供“清空本地数据”，删除：

- RawInput。
- PreprocessResult。
- CandidateEvent。
- CalendarEvent。
- CustomField。
- LLMTrace。

## 后续真实 LLM

云端模型接入后的现有控制：

- API Key 保存到 iOS Keychain。
- OCR 和 LLM 可以分别选择 Provider、Base URL 和模型名。
- “测试并获取模型”只调用当前 Provider 的 `/models` 接口，不提交用户内容。
- 默认不保存原始 LLM 响应，只保存响应 hash。
- 可开启云端失败后本地规则回退。

后续正式产品化前仍需增加：

1. 发送内容预览。
2. 用户显式同意。
3. 后端代理和服务端密钥托管。
4. 敏感日志脱敏。
5. 更细粒度的 LLMTrace 隐私模式。
