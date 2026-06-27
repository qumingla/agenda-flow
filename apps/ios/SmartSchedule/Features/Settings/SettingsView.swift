import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultReminderMinutes") private var defaultReminderMinutes = 30
    @AppStorage("defaultDurationMinutes") private var defaultDurationMinutes = 60
    @AppStorage("workdayStartHour") private var workdayStartHour = 9
    @AppStorage("workdayEndHour") private var workdayEndHour = 18
    @AppStorage(LLMPreferencesKey.cloudEnabled) private var cloudLLMEnabled = false
    @AppStorage(LLMPreferencesKey.privacyLocalOnly) private var privacyLocalOnly = true
    @AppStorage(LLMPreferencesKey.provider) private var providerRaw = LLMProviderPreset.local.rawValue
    @AppStorage(LLMPreferencesKey.baseURL) private var llmBaseURL = ""
    @AppStorage(LLMPreferencesKey.modelName) private var llmModelName = ""
    @AppStorage(LLMPreferencesKey.useJSONMode) private var llmUseJSONMode = true
    @AppStorage(LLMPreferencesKey.saveRawResponse) private var llmSaveRawResponse = false
    @AppStorage(LLMPreferencesKey.fallbackToMock) private var llmFallbackToMock = true
    @AppStorage(LLMPreferencesKey.timeoutSeconds) private var llmTimeoutSeconds = 60.0
    @AppStorage(LLMPreferencesKey.fetchedModels) private var fetchedModelsBlob = ""

    @State private var showDeleteConfirmation = false
    @State private var deleteMessage: String?
    @State private var apiKeyInput = ""
    @State private var hasSavedAPIKey = false
    @State private var keyStatusMessage: String?
    @State private var isFetchingModels = false
    @State private var modelFetchMessage: String?

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

            Section("隐私") {
                Toggle("仅本地处理", isOn: $privacyLocalOnly)
                    .onChange(of: privacyLocalOnly) { _, newValue in
                        if newValue {
                            cloudLLMEnabled = false
                        }
                    }
                Toggle("启用云端 LLM", isOn: $cloudLLMEnabled)
                    .disabled(selectedProvider == .local)
                    .onChange(of: cloudLLMEnabled) { _, newValue in
                        if newValue {
                            privacyLocalOnly = false
                        }
                    }
                Text("开启云端 LLM 后，文本或 OCR 结果会发送到你选择的模型服务。原始截图默认仍保存在本机。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            llmProviderSection

            Section("系统能力") {
                LabeledContent("OCR", value: "Apple Vision，本地")
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
            applyMissingProviderDefaults()
            loadAPIKeyState()
        }
        .onChange(of: providerRaw) { _, _ in
            applySelectedProviderDefaults()
            loadAPIKeyState()
        }
        .confirmationDialog("清空所有本地数据？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                clearLocalData()
            }
        } message: {
            Text("这会删除 Inbox、待审核草稿、内置日程、动态字段和 LLM Trace。")
        }
    }

    private var llmProviderSection: some View {
        Section("LLM Provider") {
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
                .disabled(!canFetchModels)

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

    private var fetchedModelIDs: [String] {
        fetchedModelsBlob
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var canFetchModels: Bool {
        selectedProvider != .local
            && cloudLLMEnabled
            && !privacyLocalOnly
            && !isFetchingModels
            && !llmBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

        llmBaseURL = provider.defaultBaseURL
        llmModelName = provider.defaultModel
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

    private func saveAPIKey() {
        do {
            try LLMKeychainStore.saveAPIKey(apiKeyInput, for: selectedProvider)
            apiKeyInput = ""
            loadAPIKeyState()
            keyStatusMessage = "API Key 已保存到 Keychain。"
        } catch {
            keyStatusMessage = error.localizedDescription
        }
    }

    private func clearAPIKey() {
        do {
            try LLMKeychainStore.deleteAPIKey(for: selectedProvider)
            apiKeyInput = ""
            loadAPIKeyState()
            keyStatusMessage = "API Key 已清除。"
        } catch {
            keyStatusMessage = error.localizedDescription
        }
    }

    private func fetchModels() {
        guard canFetchModels else {
            modelFetchMessage = "请先关闭仅本地处理、启用云端 LLM，并填写 Base URL。"
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
