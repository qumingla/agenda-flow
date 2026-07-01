import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultReminderMinutes") private var defaultReminderMinutes = 30
    @AppStorage("defaultDurationMinutes") private var defaultDurationMinutes = 60
    @AppStorage("workdayStartHour") private var workdayStartHour = 9
    @AppStorage("workdayEndHour") private var workdayEndHour = 18
    @AppStorage(LLMPreferencesKey.cloudEnabled) private var cloudLLMEnabled = true
    @AppStorage(LLMPreferencesKey.privacyLocalOnly) private var privacyLocalOnly = false
    @AppStorage(LLMPreferencesKey.provider) private var providerRaw = LLMProviderPreset.openAI.rawValue
    @AppStorage(LLMPreferencesKey.baseURL) private var llmBaseURL = ""
    @AppStorage(LLMPreferencesKey.modelName) private var llmModelName = ""
    @AppStorage(LLMPreferencesKey.useJSONMode) private var llmUseJSONMode = true
    @AppStorage(LLMPreferencesKey.saveRawResponse) private var llmSaveRawResponse = false
    @AppStorage(LLMPreferencesKey.fallbackToMock) private var llmFallbackToMock = true
    @AppStorage(LLMPreferencesKey.timeoutSeconds) private var llmTimeoutSeconds = 60.0
    @AppStorage(LLMPreferencesKey.fetchedModels) private var fetchedModelsBlob = ""
    @AppStorage(OCRPreferencesKey.mode) private var ocrModeRaw = OCRProviderMode.localAppleVision.rawValue
    @AppStorage(OCRPreferencesKey.provider) private var ocrProviderRaw = LLMProviderPreset.openAI.rawValue
    @AppStorage(OCRPreferencesKey.baseURL) private var ocrBaseURL = ""
    @AppStorage(OCRPreferencesKey.modelName) private var ocrModelName = ""
    @AppStorage(OCRPreferencesKey.timeoutSeconds) private var ocrTimeoutSeconds = 60.0
    @AppStorage(OCRPreferencesKey.fallbackToLocal) private var ocrFallbackToLocal = true
    @AppStorage(OCRPreferencesKey.fetchedModels) private var ocrFetchedModelsBlob = ""

    @State private var showDeleteConfirmation = false
    @State private var deleteMessage: String?
    @State private var apiKeyInput = ""
    @State private var hasSavedAPIKey = false
    @State private var keyStatusMessage: String?
    @State private var isFetchingModels = false
    @State private var modelFetchMessage: String?
    @State private var ocrAPIKeyInput = ""
    @State private var ocrHasSavedAPIKey = false
    @State private var ocrKeyStatusMessage: String?
    @State private var isFetchingOCRModels = false
    @State private var ocrModelFetchMessage: String?

    var body: some View {
        Form {
            Section("默认规划") {
                Stepper(value: $defaultDurationMinutes, in: 15...240, step: 15) {
                    LabeledContent("默认时长", value: "\(defaultDurationMinutes) 分钟")
                }
                Stepper(value: $defaultReminderMinutes, in: 0...180, step: 5) {
                    LabeledContent("默认提醒", value: defaultReminderMinutes == 0 ? "不提醒" : "提前 \(defaultReminderMinutes) 分钟")
                }
                Stepper(value: $workdayStartHour, in: 0...23) {
                    LabeledContent("工作开始", value: "\(workdayStartHour):00")
                }
                Stepper(value: $workdayEndHour, in: 1...24) {
                    LabeledContent("工作结束", value: "\(workdayEndHour):00")
                }
            }

            Section("云端与隐私") {
                Toggle("强制全本地处理", isOn: $privacyLocalOnly)
                    .onChange(of: privacyLocalOnly) { _, newValue in
                        if newValue {
                            cloudLLMEnabled = false
                            ocrModeRaw = OCRProviderMode.localAppleVision.rawValue
                        }
                    }
                Text("默认是本地 OCR、云端 LLM 规整。打开全本地处理后，图片和文本都不会发往云端模型。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ocrProviderSection

            llmProviderSection

            Section("系统能力") {
                LabeledContent("OCR", value: ocrEngineLabel)
                LabeledContent("结构化提取", value: extractionEngineLabel)
                LabeledContent("日历同步", value: "协议预留")
                LabeledContent("Share Extension", value: "后续阶段")
            }

            Section("数据控制") {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("清空本地数据", systemImage: "trash")
                }

                if let deleteMessage {
                    Text(deleteMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("版本") {
                LabeledContent("版本", value: "0.1.0-beta")
                LabeledContent("数据源", value: "SwiftData 本地存储")
                NavigationLink("查看实施计划") {
                    DocumentHintView()
                }
            }
        }
        .navigationTitle("设置")
        .onAppear {
            RuntimePreferencesBootstrap.applyIfNeeded()
            applyMissingProviderDefaults()
            applyMissingOCRProviderDefaults()
            loadAPIKeyState()
            loadOCRAPIKeyState()
        }
        .onChange(of: providerRaw) { _, _ in
            applySelectedProviderDefaults()
            loadAPIKeyState()
        }
        .onChange(of: ocrProviderRaw) { _, _ in
            applySelectedOCRProviderDefaults()
            loadOCRAPIKeyState()
        }
        .onChange(of: ocrModeRaw) { _, newValue in
            if OCRProviderMode(rawValue: newValue) == .cloudVisionModel {
                privacyLocalOnly = false
                applyMissingOCRProviderDefaults()
                loadOCRAPIKeyState()
            }
        }
        .confirmationDialog("清空所有本地数据？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                clearLocalData()
            }
        } message: {
            Text("这会删除 Inbox、待审核草稿、内置日程、动态字段和 LLM Trace。")
        }
    }

    private var ocrProviderSection: some View {
        Section("OCR 识别") {
            Picker("OCR 方式", selection: $ocrModeRaw) {
                ForEach(OCRProviderMode.allCases) { mode in
                    Text(mode.displayName).tag(mode.rawValue)
                }
            }
            .disabled(privacyLocalOnly)

            Text(selectedOCRMode.helpText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if selectedOCRMode == .cloudVisionModel {
                Picker("服务商", selection: $ocrProviderRaw) {
                    ForEach(LLMProviderPreset.allCases.filter { $0 != .local }) { provider in
                        Text(provider.displayName).tag(provider.rawValue)
                    }
                }

                Text(selectedOCRProvider.helpText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField("Base URL", text: $ocrBaseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                TextField("手动填写 OCR 模型名", text: $ocrModelName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !ocrFetchedModelIDs.isEmpty {
                    Picker("使用 OCR 模型", selection: $ocrModelName) {
                        if ocrModelName.isEmpty {
                            Text("请选择模型").tag("")
                        }
                        if !ocrModelName.isEmpty, !ocrFetchedModelIDs.contains(ocrModelName) {
                            Text("当前：\(ocrModelName)").tag(ocrModelName)
                        }
                        ForEach(ocrFetchedModelIDs, id: \.self) { modelID in
                            Text(modelID).tag(modelID)
                        }
                    }
                }

                SecureField(ocrHasSavedAPIKey ? "已保存 Key，输入新 Key 可替换" : "API Key", text: $ocrAPIKeyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                HStack {
                    Button {
                        saveOCRAPIKey()
                    } label: {
                        Label("保存 Key", systemImage: "key")
                    }
                    .disabled(ocrAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()

                    Button(role: .destructive) {
                        clearOCRAPIKey()
                    } label: {
                        Label("清除", systemImage: "xmark.circle")
                    }
                    .disabled(!ocrHasSavedAPIKey)
                }

                if let ocrKeyStatusMessage {
                    Text(ocrKeyStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Toggle("云端 OCR 失败时回退 Apple Vision", isOn: $ocrFallbackToLocal)

                Stepper(value: $ocrTimeoutSeconds, in: 15...180, step: 15) {
                    LabeledContent("请求超时", value: "\(Int(ocrTimeoutSeconds)) 秒")
                }

                Button {
                    fetchOCRModels()
                } label: {
                    if isFetchingOCRModels {
                        Label("正在获取 OCR 模型", systemImage: "arrow.triangle.2.circlepath")
                    } else {
                        Label("测试并获取 OCR 模型", systemImage: "network")
                    }
                }
                .disabled(isFetchingOCRModels)

                if let ocrModelFetchMessage {
                    Text(ocrModelFetchMessage)
                        .font(.footnote)
                        .foregroundStyle(ocrModelFetchMessage.contains("失败") || ocrModelFetchMessage.contains("不可用") ? .red : .secondary)
                }

                Text("获取模型只调用当前 OCR Base URL 的 `/models` 接口。获取成功后，请手动选择用于图片文字识别的视觉模型。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var llmProviderSection: some View {
        Section("LLM 规整") {
            Toggle("启用云端 LLM", isOn: $cloudLLMEnabled)
                .disabled(selectedProvider == .local || privacyLocalOnly)
                .onChange(of: cloudLLMEnabled) { _, newValue in
                    if newValue {
                        privacyLocalOnly = false
                    }
                }

            Picker("服务商", selection: $providerRaw) {
                ForEach(LLMProviderPreset.allCases) { provider in
                    Text(provider.displayName).tag(provider.rawValue)
                }
            }

            Text(selectedProvider.helpText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if selectedProvider != .local {
                TextField("Base URL", text: $llmBaseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                TextField("手动填写模型名", text: $llmModelName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !fetchedModelIDs.isEmpty {
                    Picker("使用模型", selection: $llmModelName) {
                        if llmModelName.isEmpty {
                            Text("请选择模型").tag("")
                        }
                        if !llmModelName.isEmpty, !fetchedModelIDs.contains(llmModelName) {
                            Text("当前：\(llmModelName)").tag(llmModelName)
                        }
                        ForEach(fetchedModelIDs, id: \.self) { modelID in
                            Text(modelID).tag(modelID)
                        }
                    }
                }

                SecureField(hasSavedAPIKey ? "已保存 Key，输入新 Key 可替换" : "API Key", text: $apiKeyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                HStack {
                    Button {
                        saveAPIKey()
                    } label: {
                        Label("保存 Key", systemImage: "key")
                    }
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()

                    Button(role: .destructive) {
                        clearAPIKey()
                    } label: {
                        Label("清除", systemImage: "xmark.circle")
                    }
                    .disabled(!hasSavedAPIKey)
                }

                if let keyStatusMessage {
                    Text(keyStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Toggle("JSON Mode", isOn: $llmUseJSONMode)
                Toggle("云端失败时回退本地规则", isOn: $llmFallbackToMock)
                Toggle("保存原始 LLM 响应", isOn: $llmSaveRawResponse)

                Stepper(value: $llmTimeoutSeconds, in: 15...180, step: 15) {
                    LabeledContent("请求超时", value: "\(Int(llmTimeoutSeconds)) 秒")
                }

                Button {
                    fetchModels()
                } label: {
                    if isFetchingModels {
                        Label("正在获取模型", systemImage: "arrow.triangle.2.circlepath")
                    } else {
                        Label("测试并获取模型", systemImage: "network")
                    }
                }
                .disabled(isFetchingModels)

                if let modelFetchMessage {
                    Text(modelFetchMessage)
                        .font(.footnote)
                        .foregroundStyle(modelFetchMessage.contains("失败") || modelFetchMessage.contains("不可用") ? .red : .secondary)
                }

                Text("获取模型只会调用当前 Base URL 的 `/models` 接口。获取成功后，请在“使用模型”中手动选择后续解析要用的模型。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var selectedProvider: LLMProviderPreset {
        LLMProviderPreset(rawValue: providerRaw) ?? .local
    }

    private var selectedOCRMode: OCRProviderMode {
        OCRProviderMode(rawValue: ocrModeRaw) ?? .localAppleVision
    }

    private var selectedOCRProvider: LLMProviderPreset {
        let provider = LLMProviderPreset(rawValue: ocrProviderRaw) ?? .openAI
        return provider == .local ? .openAI : provider
    }

    private var fetchedModelIDs: [String] {
        fetchedModelsBlob
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var ocrFetchedModelIDs: [String] {
        ocrFetchedModelsBlob
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var ocrEngineLabel: String {
        guard !privacyLocalOnly, selectedOCRMode == .cloudVisionModel else {
            return "Apple Vision，本地"
        }
        let model = ocrModelName.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.isEmpty ? "\(selectedOCRProvider.displayName)，未选择 OCR 模型" : "\(selectedOCRProvider.displayName)，\(model)"
    }

    private var extractionEngineLabel: String {
        guard cloudLLMEnabled, !privacyLocalOnly, selectedProvider != .local else {
            return "MockLLMService，本地"
        }
        let model = llmModelName.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.isEmpty ? "\(selectedProvider.displayName)，未选择模型" : "\(selectedProvider.displayName)，\(model)"
    }

    private func applyMissingProviderDefaults() {
        guard selectedProvider != .local else {
            return
        }
        if llmBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            llmBaseURL = selectedProvider.defaultBaseURL
        }
        if llmModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            llmModelName = selectedProvider.defaultModel
        }
    }

    private func applySelectedProviderDefaults() {
        let provider = selectedProvider
        apiKeyInput = ""
        keyStatusMessage = nil
        modelFetchMessage = nil
        fetchedModelsBlob = ""

        if provider == .local {
            cloudLLMEnabled = false
            llmBaseURL = ""
            llmModelName = provider.defaultModel
            return
        }

        if !privacyLocalOnly {
            cloudLLMEnabled = true
        }
        llmBaseURL = provider.defaultBaseURL
        llmModelName = provider.defaultModel
    }

    private func applyMissingOCRProviderDefaults() {
        if ocrProviderRaw == LLMProviderPreset.local.rawValue {
            ocrProviderRaw = LLMProviderPreset.openAI.rawValue
        }
        if ocrBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ocrBaseURL = selectedOCRProvider.defaultBaseURL
        }
        if ocrModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ocrModelName = selectedOCRProvider.defaultModel
        }
    }

    private func applySelectedOCRProviderDefaults() {
        let provider = selectedOCRProvider
        ocrAPIKeyInput = ""
        ocrKeyStatusMessage = nil
        ocrModelFetchMessage = nil
        ocrFetchedModelsBlob = ""

        ocrProviderRaw = provider.rawValue
        ocrBaseURL = provider.defaultBaseURL
        ocrModelName = provider.defaultModel
    }

    private func loadAPIKeyState() {
        guard selectedProvider != .local else {
            hasSavedAPIKey = false
            keyStatusMessage = nil
            return
        }

        do {
            let apiKey = try LLMKeychainStore.readAPIKey(for: selectedProvider)
            hasSavedAPIKey = !apiKey.isEmpty
            keyStatusMessage = hasSavedAPIKey ? "API Key 已保存在 Keychain。" : "尚未保存 API Key。"
        } catch {
            hasSavedAPIKey = false
            keyStatusMessage = error.localizedDescription
        }
    }

    private func loadOCRAPIKeyState() {
        guard selectedOCRMode == .cloudVisionModel else {
            ocrHasSavedAPIKey = false
            ocrKeyStatusMessage = nil
            return
        }

        do {
            let apiKey = try LLMKeychainStore.readAPIKey(for: selectedOCRProvider)
            ocrHasSavedAPIKey = !apiKey.isEmpty
            ocrKeyStatusMessage = ocrHasSavedAPIKey ? "API Key 已保存在 Keychain。" : "尚未保存 API Key。"
        } catch {
            ocrHasSavedAPIKey = false
            ocrKeyStatusMessage = error.localizedDescription
        }
    }

    private func saveAPIKey() {
        do {
            try LLMKeychainStore.saveAPIKey(apiKeyInput, for: selectedProvider)
            apiKeyInput = ""
            loadAPIKeyState()
            loadOCRAPIKeyState()
            keyStatusMessage = "API Key 已保存到 Keychain。"
        } catch {
            keyStatusMessage = error.localizedDescription
        }
    }

    private func saveOCRAPIKey() {
        do {
            try LLMKeychainStore.saveAPIKey(ocrAPIKeyInput, for: selectedOCRProvider)
            ocrAPIKeyInput = ""
            loadOCRAPIKeyState()
            loadAPIKeyState()
            ocrKeyStatusMessage = "API Key 已保存到 Keychain。"
        } catch {
            ocrKeyStatusMessage = error.localizedDescription
        }
    }

    private func clearAPIKey() {
        do {
            try LLMKeychainStore.deleteAPIKey(for: selectedProvider)
            apiKeyInput = ""
            loadAPIKeyState()
            loadOCRAPIKeyState()
            keyStatusMessage = "API Key 已清除。"
        } catch {
            keyStatusMessage = error.localizedDescription
        }
    }

    private func clearOCRAPIKey() {
        do {
            try LLMKeychainStore.deleteAPIKey(for: selectedOCRProvider)
            ocrAPIKeyInput = ""
            loadOCRAPIKeyState()
            loadAPIKeyState()
            ocrKeyStatusMessage = "API Key 已清除。"
        } catch {
            ocrKeyStatusMessage = error.localizedDescription
        }
    }

    private func fetchModels() {
        guard selectedProvider != .local else {
            modelFetchMessage = "请先选择一个云端 Provider。"
            return
        }
        guard !privacyLocalOnly else {
            modelFetchMessage = "请先关闭“强制全本地处理”，否则不会发起云端测试。"
            return
        }
        guard cloudLLMEnabled else {
            modelFetchMessage = "请先启用云端 LLM。"
            return
        }
        guard !llmBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            modelFetchMessage = "请先填写 Base URL。"
            return
        }
        guard hasSavedAPIKey || !apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            modelFetchMessage = "请先输入 API Key，或保存已输入的 Key。"
            return
        }

        isFetchingModels = true
        modelFetchMessage = nil

        Task {
            do {
                if !apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    try LLMKeychainStore.saveAPIKey(apiKeyInput, for: selectedProvider)
                    apiKeyInput = ""
                    loadAPIKeyState()
                    loadOCRAPIKeyState()
                }

                let models = try await LLMServiceFactory.fetchAvailableModels()
                let modelIDs = models.map(\.id)
                fetchedModelsBlob = modelIDs.joined(separator: "\n")
                modelFetchMessage = "测试通过，获取到 \(modelIDs.count) 个模型。请手动选择使用模型。"
            } catch {
                modelFetchMessage = "测试失败：\(error.localizedDescription)"
            }
            isFetchingModels = false
        }
    }

    private func fetchOCRModels() {
        guard selectedOCRMode == .cloudVisionModel else {
            ocrModelFetchMessage = "请先把 OCR 方式切换为云端视觉模型。"
            return
        }
        guard !privacyLocalOnly else {
            ocrModelFetchMessage = "请先关闭“强制全本地处理”，否则不会发起云端测试。"
            return
        }
        guard !ocrBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            ocrModelFetchMessage = "请先填写 OCR Base URL。"
            return
        }
        guard ocrHasSavedAPIKey || !ocrAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            ocrModelFetchMessage = "请先输入 API Key，或保存已输入的 Key。"
            return
        }

        isFetchingOCRModels = true
        ocrModelFetchMessage = nil

        Task {
            do {
                if !ocrAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    try LLMKeychainStore.saveAPIKey(ocrAPIKeyInput, for: selectedOCRProvider)
                    ocrAPIKeyInput = ""
                    loadOCRAPIKeyState()
                    loadAPIKeyState()
                }

                let models = try await OCRServiceFactory.fetchAvailableModels()
                let modelIDs = models.map(\.id)
                ocrFetchedModelsBlob = modelIDs.joined(separator: "\n")
                ocrModelFetchMessage = "测试通过，获取到 \(modelIDs.count) 个模型。请手动选择 OCR 模型。"
            } catch {
                ocrModelFetchMessage = "测试失败：\(error.localizedDescription)"
            }
            isFetchingOCRModels = false
        }
    }

    private func clearLocalData() {
        do {
            try deleteAll(LLMTraceModel.self)
            try deleteAll(CustomFieldModel.self)
            try deleteAll(CalendarEventModel.self)
            try deleteAll(CandidateEventModel.self)
            try deleteAll(PreprocessResultModel.self)
            try deleteAll(RawInputModel.self)
            try modelContext.save()
            deleteMessage = "本地数据已清空。"
        } catch {
            deleteMessage = error.localizedDescription
        }
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        let descriptor = FetchDescriptor<T>()
        let models = try modelContext.fetch(descriptor)
        for model in models {
            modelContext.delete(model)
        }
    }
}

private struct DocumentHintView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("文档位置")
                    .font(.title.bold())
                Text("项目根目录包含 `DETAILED_PLAN.md`、`README.md`、`docs/`、`schemas/` 和 `prompts/`。这些文件随代码一起纳入版本控制。")
                    .textSelection(.enabled)
                Text("后续真实 LLM、EventKit、Share Extension 会按文档中的阶段继续接入。")
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("文档")
    }
}
