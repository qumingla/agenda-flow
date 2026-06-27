import SwiftData
import SwiftUI

struct ReviewView: View {
    @Query(sort: \CandidateEventModel.createdAt, order: .reverse) private var candidates: [CandidateEventModel]

    private var activeCandidates: [CandidateEventModel] {
        candidates.filter { ![.converted, .rejected].contains($0.status) }
    }

    var body: some View {
        Group {
            if activeCandidates.isEmpty {
                EmptyStateView(
                    icon: "checklist.checked",
                    title: "没有待审核草稿",
                    message: "候选日程会先出现在这里，确认后才进入正式日程。"
                )
            } else {
                List {
                    ForEach(activeCandidates) { candidate in
                        NavigationLink {
                            ReviewDetailView(candidate: candidate)
                        } label: {
                            CandidateRow(candidate: candidate)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("待审核")
    }
}

private struct CandidateRow: View {
    var candidate: CandidateEventModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(candidate.titleValue)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(candidate.status.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusColor)
            }

            HStack(spacing: 12) {
                Label(candidate.startDate?.betaShortDateTime ?? "时间待确认", systemImage: "clock")
                Label(candidate.locationName.isEmpty ? candidate.locationType.displayName : candidate.locationName, systemImage: candidate.locationType.iconName)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                ConfidenceGauge(value: candidate.overallConfidence)
                Spacer()
                Text(candidate.rawInput?.inputType.displayName ?? "来源未知")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch candidate.status {
        case .needsTime, .needsLocation, .lowConfidence: .orange
        case .readyForReview: .green
        case .rejected: .red
        default: .secondary
        }
    }
}

struct ReviewDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultDurationMinutes") private var defaultDurationMinutes = 60
    @AppStorage("defaultReminderMinutes") private var defaultReminderMinutes = 30

    @Bindable var candidate: CandidateEventModel
    @State private var errorMessage: String?
    @State private var createdEvent: CalendarEventModel?

    var body: some View {
        Form {
            Section("审核状态") {
                LabeledContent("当前状态", value: candidate.status.displayName)
                ConfidenceGauge(value: candidate.overallConfidence)
                if !candidate.questions.isEmpty {
                    ForEach(candidate.questions, id: \.self) { question in
                        Label(question, systemImage: "questionmark.circle")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section("核心字段") {
                TextField("标题", text: Binding(
                    get: { candidate.titleValue },
                    set: {
                        candidate.titleValue = $0
                        candidate.touchAndLock("title")
                    }
                ))

                Toggle("全天", isOn: $candidate.isAllDay)

                DatePicker("开始", selection: Binding(
                    get: { candidate.startDate ?? Date() },
                    set: {
                        candidate.startDate = $0
                        candidate.timeStatus = .confirmed
                        candidate.touchAndLock("time.start")
                    }
                ), displayedComponents: candidate.isAllDay ? [.date] : [.date, .hourAndMinute])

                DatePicker("结束", selection: Binding(
                    get: { candidate.endDate ?? Calendar.current.date(byAdding: .minute, value: defaultDurationMinutes, to: candidate.startDate ?? Date()) ?? Date() },
                    set: {
                        candidate.endDate = $0
                        candidate.touchAndLock("time.end")
                    }
                ), displayedComponents: candidate.isAllDay ? [.date] : [.date, .hourAndMinute])

                Picker("时间状态", selection: Binding(
                    get: { candidate.timeStatus },
                    set: { candidate.timeStatus = $0 }
                )) {
                    ForEach(TimeFieldStatus.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }

                Picker("地点类型", selection: Binding(
                    get: { candidate.locationType },
                    set: { candidate.locationType = $0 }
                )) {
                    ForEach(LocationType.allCases) { type in
                        Label(type.displayName, systemImage: type.iconName).tag(type)
                    }
                }

                TextField("地点名称", text: Binding(
                    get: { candidate.locationName },
                    set: {
                        candidate.locationName = $0
                        candidate.locationStatus = .confirmed
                        candidate.touchAndLock("location.name")
                    }
                ))

                Picker("优先级", selection: Binding(
                    get: { candidate.priority },
                    set: { candidate.priority = $0 }
                )) {
                    ForEach(PriorityLevel.allCases) { priority in
                        Text(priority.displayName).tag(priority)
                    }
                }

                TextField("备注", text: Binding(
                    get: { candidate.notes },
                    set: {
                        candidate.notes = $0
                        candidate.touchAndLock("notes")
                    }
                ), axis: .vertical)
                .lineLimit(3...8)
            }

            Section("动态字段") {
                DynamicFieldsView(ownerType: .candidateEvent, ownerID: candidate.id)
            }

            Section("LLM 依据") {
                LabeledContent("标题依据", value: candidate.titleSourceText)
                LabeledContent("时间依据", value: candidate.timeSourceText.isEmpty ? "无" : candidate.timeSourceText)
                LabeledContent("地点依据", value: candidate.locationSourceText.isEmpty ? "无" : candidate.locationSourceText)
                Text(candidate.sourceSummary)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    submit()
                } label: {
                    Label("提交到日程表", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    candidate.status = .rejected
                    try? modelContext.save()
                } label: {
                    Label("不是日程，忽略", systemImage: "xmark.circle")
                }
            }
        }
        .navigationTitle(candidate.titleValue.isEmpty ? "审核草稿" : candidate.titleValue)
        .navigationBarTitleDisplayMode(.inline)
        .alert("无法提交", isPresented: .constant(errorMessage != nil)) {
            Button("好") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .navigationDestination(item: $createdEvent) { event in
            CalendarEventDetailView(event: event)
        }
    }

    private func submit() {
        do {
            let event = try BetaPlanningService().createCalendarEvent(
                from: candidate,
                context: modelContext,
                defaultDurationMinutes: defaultDurationMinutes,
                defaultReminderMinutes: defaultReminderMinutes
            )
            let notificationSnapshot = NotificationEventSnapshot(event: event)
            Task {
                await NotificationScheduler().scheduleNotifications(for: notificationSnapshot)
            }
            createdEvent = event
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct DynamicFieldsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var fields: [CustomFieldModel]

    private let ownerType: OwnerType
    private let ownerID: UUID

    init(ownerType: OwnerType, ownerID: UUID) {
        self.ownerType = ownerType
        self.ownerID = ownerID
        let ownerTypeRaw = ownerType.rawValue
        _fields = Query(
            filter: #Predicate<CustomFieldModel> { field in
                field.ownerID == ownerID && field.ownerTypeRaw == ownerTypeRaw
            },
            sort: \.createdAt
        )
    }

    var body: some View {
        if fields.isEmpty {
            Text("暂无动态字段。")
                .foregroundStyle(.secondary)
        } else {
            ForEach(fields) { field in
                DynamicFieldRow(field: field)
            }
            .onDelete(perform: delete)
        }

        Button {
            addField()
        } label: {
            Label("新增字段", systemImage: "plus.circle")
        }
    }

    private func addField() {
        let field = CustomFieldModel(
            ownerType: ownerType,
            ownerID: ownerID,
            key: "custom_\(fields.count + 1)",
            label: "自定义字段",
            type: .string,
            value: "",
            source: .user,
            isUserModified: true,
            lockStatus: .userLocked
        )
        modelContext.insert(field)
        try? modelContext.save()
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(fields[index])
        }
        try? modelContext.save()
    }
}

private struct DynamicFieldRow: View {
    @Bindable var field: CustomFieldModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("字段名", text: Binding(
                get: { field.label },
                set: {
                    field.label = $0
                    field.markUserModified()
                }
            ))
            .font(.subheadline.weight(.semibold))

            Picker("类型", selection: Binding(
                get: { field.fieldType },
                set: { field.fieldType = $0 }
            )) {
                ForEach(CustomFieldType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }

            fieldValueEditor

            if !field.sourceText.isEmpty {
                Text("来源：\(field.sourceText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var fieldValueEditor: some View {
        switch field.fieldType {
        case .boolean:
            Toggle("值", isOn: Binding(
                get: { field.value == "true" },
                set: {
                    field.value = $0 ? "true" : "false"
                    field.markUserModified()
                }
            ))
        case .number:
            TextField("数字", text: Binding(
                get: { field.value },
                set: {
                    field.value = $0.filter { "0123456789.-".contains($0) }
                    field.markUserModified()
                }
            ))
            .keyboardType(.decimalPad)
        case .datetime:
            DatePicker("时间", selection: Binding(
                get: {
                    ISO8601DateFormatter().date(from: field.value) ?? Date()
                },
                set: {
                    field.value = ISO8601DateFormatter().string(from: $0)
                    field.markUserModified()
                }
            ))
        case .url:
            TextField("链接", text: Binding(
                get: { field.value },
                set: {
                    field.value = $0
                    field.markUserModified()
                }
            ))
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
        default:
            TextField("值", text: Binding(
                get: { field.value },
                set: {
                    field.value = $0
                    field.markUserModified()
                }
            ), axis: .vertical)
        }
    }
}
