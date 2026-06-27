# Privacy and Security

## 默认策略

Beta 版默认本地处理：

- 文本留在本地 SwiftData。
- 图片保存在 App 沙盒文件系统。
- OCR 使用 Apple Vision 本地能力。
- Mock LLM 本地运行，不上传内容。

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

接入云端模型前必须增加：

1. 发送内容预览。
2. 用户显式同意。
3. Keychain 或后端代理。
4. 敏感日志脱敏。
5. LLMTrace 隐私模式。
