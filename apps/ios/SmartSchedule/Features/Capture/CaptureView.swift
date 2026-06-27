import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultReminderMinutes") private var defaultReminderMinutes = 30

    @State private var textInput = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let storage = LocalFileStorageService()
    private let pipeline = BetaExtractionPipeline()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                textCaptureCard
                imageCaptureCard
                betaScopeCard
            }
            .padding()
        }
        .navigationTitle("快速捕获")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isProcessing {
                    ProgressView()
                }
            }
        }
        .alert("处理失败", isPresented: .constant(errorMessage != nil)) {
            Button("好") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .overlay(alignment: .bottom) {
            if let successMessage {
                Text(successMessage)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .betaGlassPanel(tint: .green)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else {
                return
            }
            Task {
                await importPhoto(newValue)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("把零散信息先进 Inbox")
                .font(.largeTitle.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Text("Beta 版支持文本、剪贴板和相册截图。本地 OCR 后会生成待审核草稿，确认前不会进入正式日程。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .betaGlassPanel(tint: .accentColor)
    }

    private var textCaptureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("文本输入", systemImage: "text.alignleft")
                .font(.headline)

            TextEditor(text: $textInput)
                .frame(minHeight: 150)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.quaternary.opacity(0.24), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    if textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack {
                            HStack {
                                Text("例如：明天下午 3 点在国贸 B 座见张总，带合同")
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 16)
                                Spacer()
                            }
                            Spacer()
                        }
                        .allowsHitTesting(false)
                    }
                }

            HStack {
                Button {
                    pasteClipboard()
                } label: {
                    Label("剪贴板", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    Task {
                        await submitText()
                    }
                } label: {
                    Label("解析", systemImage: "wand.and.sparkles")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing || textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .betaGlassPanel()
    }

    private var imageCaptureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("截图 OCR", systemImage: "photo.on.rectangle.angled")
                .font(.headline)

            Text("选择聊天截图、活动海报或票据信息，系统会先用 Apple Vision 在本地识别文字。")
                .font(.callout)
                .foregroundStyle(.secondary)

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("选择图片", systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing)
        }
        .padding()
        .betaGlassPanel()
    }

    private var betaScopeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Beta 边界", systemImage: "shield.lefthalf.filled")
                .font(.headline)
            Text("当前版本不读取聊天 App 数据，也不会后台扫描相册。所有输入都由用户主动粘贴、输入或选择。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .betaGlassPanel(tint: .orange)
    }

    @MainActor
    private func submitText() async {
        let text = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        let rawInput = RawInputModel(
            inputType: .text,
            source: .manual,
            originalText: text,
            rawText: text,
            contentHash: BetaHash.sha256(text)
        )
        modelContext.insert(rawInput)

        do {
            try modelContext.save()
            await pipeline.processText(rawInput: rawInput, context: modelContext)
            textInput = ""
            showSuccess("已生成待审核草稿")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func importPhoto(_ item: PhotosPickerItem) async {
        isProcessing = true
        defer {
            isProcessing = false
            selectedPhoto = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw BetaAppError.imageDecodingFailed
            }

            let filePath = try storage.save(data, kind: .image, extension: "jpg")
            let thumbnailPath = try storage.makeThumbnail(from: data)
            let rawInput = RawInputModel(
                inputType: .image,
                source: .appUpload,
                originalFilePath: filePath,
                thumbnailPath: thumbnailPath,
                contentHash: BetaHash.sha256(data)
            )
            modelContext.insert(rawInput)
            try modelContext.save()
            await pipeline.processImage(rawInput: rawInput, context: modelContext)
            showSuccess("图片已识别并进入审核")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pasteClipboard() {
        guard let text = UIPasteboard.general.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "剪贴板没有可解析文本。"
            return
        }
        textInput = text
    }

    private func showSuccess(_ message: String) {
        withAnimation {
            successMessage = message
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation {
                    successMessage = nil
                }
            }
        }
    }
}
