import SwiftData
import SwiftUI
import UIKit

struct InboxView: View {
    @Query(sort: \RawInputModel.createdAt, order: .reverse) private var rawInputs: [RawInputModel]

    var body: some View {
        Group {
            if rawInputs.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "Inbox 为空",
                    message: "在捕获页输入文本或选择截图后，原始资料会先保存在这里。"
                )
            } else {
                List {
                    ForEach(rawInputs) { input in
                        NavigationLink {
                            InboxDetailView(rawInput: input)
                        } label: {
                            InboxRow(rawInput: input)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Inbox")
    }
}

private struct InboxRow: View {
    var rawInput: RawInputModel

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Label(rawInput.inputType.displayName, systemImage: rawInput.inputType.iconName)
                        .font(.headline)
                    Spacer()
                    Text(rawInput.status.displayName)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }

                Text(rawInput.displayText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(rawInput.createdAt.betaShortDateTime)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let path = rawInput.thumbnailPath,
           let image = UIImage(contentsOfFile: path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Image(systemName: rawInput.inputType.iconName)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var statusColor: Color {
        switch rawInput.status {
        case .failed: .red
        case .extracted: .green
        case .preprocessing, .extracting: .orange
        default: .secondary
        }
    }
}

private struct InboxDetailView: View {
    @Bindable var rawInput: RawInputModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sourcePreview
                metadataCard
                extractedTextCard
                failureCard
                candidatesCard
            }
            .padding()
        }
        .navigationTitle(rawInput.inputType.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var sourcePreview: some View {
        if let path = rawInput.originalFilePath,
           let image = UIImage(contentsOfFile: path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .betaGlassPanel()
        }
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("来源信息", systemImage: "info.circle")
                .font(.headline)
            LabeledContent("状态", value: rawInput.status.displayName)
            LabeledContent("来源", value: rawInput.source.displayName)
            LabeledContent("创建时间", value: rawInput.createdAt.betaShortDateTime)
            LabeledContent("Hash", value: String(rawInput.contentHash.prefix(12)))
        }
        .padding()
        .betaGlassPanel()
    }

    private var extractedTextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("文本内容", systemImage: "doc.text.magnifyingglass")
                .font(.headline)
            Text(rawInput.displayText)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .betaGlassPanel()
    }

    @ViewBuilder
    private var failureCard: some View {
        if let failureReason = rawInput.failureReason {
            VStack(alignment: .leading, spacing: 8) {
                Label("失败原因", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundStyle(.red)
                Text(failureReason)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .betaGlassPanel(tint: .red)
        }
    }

    private var candidatesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("候选日程", systemImage: "checklist")
                .font(.headline)

            if rawInput.candidates.isEmpty {
                Text("暂无候选日程。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rawInput.candidates) { candidate in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(candidate.titleValue)
                                .font(.subheadline.weight(.semibold))
                            Text(candidate.status.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        ConfidenceGauge(value: candidate.overallConfidence)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding()
        .betaGlassPanel()
    }
}
