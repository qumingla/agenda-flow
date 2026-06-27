# Privacy and Security

## 默认策略

Beta 版默认本地处理：

- 文本留在本地 SwiftData。
- 图片保存在 App 沙盒文件系统。
- OCR 使用 Apple Vision 本地能力。
- Mock LLM 本地运行，不上传内容。

用户在设置中关闭“仅本地处理”并启用云端 LLM 后，文本输入或 OCR 文本会发送到所选 OpenAI-compatible Provider。原始图片仍默认保存在本地，当前不会直接上传图片给多模态模型。

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
- Provider、Base URL、模型名由用户选择或填写。
- “测试并获取模型”只调用当前 Provider 的 `/models` 接口。
- 默认不保存原始 LLM 响应，只保存响应 hash。
- 可开启云端失败后本地规则回退。

后续正式产品化前仍需增加：

1. 发送内容预览。
2. 用户显式同意。
3. 后端代理和服务端密钥托管。
4. 敏感日志脱敏。
5. 更细粒度的 LLMTrace 隐私模式。
