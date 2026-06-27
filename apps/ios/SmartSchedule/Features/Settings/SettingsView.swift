import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultReminderMinutes") private var defaultReminderMinutes = 30
    @AppStorage("defaultDurationMinutes") private var defaultDurationMinutes = 60
    @AppStorage("workdayStartHour") private var workdayStartHour = 9
    @AppStorage("workdayEndHour") private var workdayEndHour = 18
    @AppStorage("cloudLLMEnabled") private var cloudLLMEnabled = false
    @AppStorage("privacyLocalOnly") private var privacyLocalOnly = true

    @State private var showDeleteConfirmation = false
    @State private var deleteMessage: String?

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
                Toggle("启用云端 LLM", isOn: $cloudLLMEnabled)
                    .disabled(privacyLocalOnly)
                Text("Beta 版当前使用本地 Mock LLM，不会上传文本、截图或音频。该开关为后续真实 Provider 预留。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("系统能力") {
                LabeledContent("OCR", value: "Apple Vision，本地")
                LabeledContent("结构化提取", value: "MockLLMService，本地")
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
        .confirmationDialog("清空所有本地数据？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                clearLocalData()
            }
        } message: {
            Text("这会删除 Inbox、待审核草稿、内置日程、动态字段和 LLM Trace。")
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
