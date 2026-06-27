import SwiftData
import SwiftUI

struct CalendarHomeView: View {
    @Query(sort: \CalendarEventModel.startDate) private var events: [CalendarEventModel]
    @State private var searchText = ""
    @State private var selectedScope = Scope.today

    private enum Scope: String, CaseIterable, Identifiable {
        case today = "今日"
        case upcoming = "未来"
        case all = "全部"

        var id: String { rawValue }
    }

    private var filteredEvents: [CalendarEventModel] {
        let calendar = Calendar.current
        return events.filter { event in
            let scopeMatches: Bool = switch selectedScope {
            case .today:
                calendar.isDateInToday(event.startDate)
            case .upcoming:
                event.startDate >= calendar.startOfDay(for: Date())
            case .all:
                true
            }

            let textMatches = searchText.isEmpty
                || event.title.localizedCaseInsensitiveContains(searchText)
                || event.locationName.localizedCaseInsensitiveContains(searchText)
                || event.notes.localizedCaseInsensitiveContains(searchText)

            return scopeMatches && textMatches && event.status != .deleted
        }
    }

    var body: some View {
        Group {
            if events.isEmpty {
                EmptyStateView(
                    icon: "calendar",
                    title: "暂无正式日程",
                    message: "审核草稿并提交后，日程会出现在这里。"
                )
            } else {
                List {
                    Section {
                        Picker("范围", selection: $selectedScope) {
                            ForEach(Scope.allCases) { scope in
                                Text(scope.rawValue).tag(scope)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if filteredEvents.isEmpty {
                        Text("没有符合条件的日程。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(groupedEvents, id: \.day) { group in
                            Section(group.day.formatted(date: .abbreviated, time: .omitted)) {
                                ForEach(group.events) { event in
                                    NavigationLink {
                                        CalendarEventDetailView(event: event)
                                    } label: {
                                        CalendarEventRow(event: event)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(text: $searchText, prompt: "搜索标题、地点或备注")
            }
        }
        .navigationTitle("日程")
    }

    private var groupedEvents: [(day: Date, events: [CalendarEventModel])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredEvents) { event in
            calendar.startOfDay(for: event.startDate)
        }
        return groups
            .map { ($0.key, $0.value.sorted { $0.startDate < $1.startDate }) }
            .sorted { $0.day < $1.day }
    }
}

private struct CalendarEventRow: View {
    var event: CalendarEventModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(event.startDate.betaTimeOnly)
                    .font(.headline.monospacedDigit())
                Text(event.endDate.betaTimeOnly)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(width: 62, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Label(event.locationName.isEmpty ? event.locationType.displayName : event.locationName, systemImage: event.locationType.iconName)
                    Label(event.priority.displayName, systemImage: "flag")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !event.notes.isEmpty {
                    Text(event.notes)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CalendarEventDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var event: CalendarEventModel
    @State private var deleteConfirmation = false

    var body: some View {
        Form {
            Section("基础信息") {
                TextField("标题", text: Binding(
                    get: { event.title },
                    set: {
                        event.title = $0
                        event.touch("title")
                    }
                ))

                Toggle("全天", isOn: $event.isAllDay)

                DatePicker("开始", selection: Binding(
                    get: { event.startDate },
                    set: {
                        event.startDate = $0
                        event.touch("time.start")
                    }
                ), displayedComponents: event.isAllDay ? [.date] : [.date, .hourAndMinute])

                DatePicker("结束", selection: Binding(
                    get: { event.endDate },
                    set: {
                        event.endDate = $0
                        event.touch("time.end")
                    }
                ), displayedComponents: event.isAllDay ? [.date] : [.date, .hourAndMinute])

                Picker("地点类型", selection: Binding(
                    get: { event.locationType },
                    set: { event.locationType = $0 }
                )) {
                    ForEach(LocationType.allCases) { type in
                        Label(type.displayName, systemImage: type.iconName).tag(type)
                    }
                }

                TextField("地点", text: Binding(
                    get: { event.locationName },
                    set: {
                        event.locationName = $0
                        event.touch("location.name")
                    }
                ))

                Picker("优先级", selection: Binding(
                    get: { event.priority },
                    set: { event.priority = $0 }
                )) {
                    ForEach(PriorityLevel.allCases) { priority in
                        Text(priority.displayName).tag(priority)
                    }
                }

                TextField("备注", text: Binding(
                    get: { event.notes },
                    set: {
                        event.notes = $0
                        event.touch("notes")
                    }
                ), axis: .vertical)
                .lineLimit(3...8)
            }

            Section("提醒") {
                if event.reminders.isEmpty {
                    Text("未设置提醒。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(event.reminders, id: \.self) { minutes in
                        Label("提前 \(minutes) 分钟", systemImage: "bell")
                    }
                }

                Button {
                    event.reminders = [30]
                    event.touch("reminders")
                    let notificationSnapshot = NotificationEventSnapshot(event: event)
                    Task {
                        await NotificationScheduler().scheduleNotifications(for: notificationSnapshot)
                    }
                } label: {
                    Label("设置提前 30 分钟提醒", systemImage: "bell.badge")
                }
            }

            Section("动态字段") {
                DynamicFieldsView(ownerType: .calendarEvent, ownerID: event.id)
            }

            Section("追溯") {
                LabeledContent("来源候选", value: event.sourceCandidateID?.uuidString.prefix(8).description ?? "手动")
                LabeledContent("状态", value: event.status.displayName)
                LabeledContent("创建时间", value: event.createdAt.betaShortDateTime)
            }

            Section {
                Button(role: .destructive) {
                    deleteConfirmation = true
                } label: {
                    Label("删除日程", systemImage: "trash")
                }
            }
        }
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("删除这个日程？", isPresented: $deleteConfirmation, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                event.status = .deleted
                try? modelContext.save()
            }
        }
    }
}
