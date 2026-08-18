//
//  ModelManagerView.swift
//  模型管理：显示已导入模型，支持从 Files App 导入
//

import SwiftUI
import UniformTypeIdentifiers

struct ModelFile: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let type: ModelType
    let modified: Date

    enum ModelType: String {
        case gguf = "GGUF"
        case mmproj = "MMProj"
    }

    var sizeText: String {
        let gb = Double(size) / 1_073_741_824
        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        } else {
            let mb = Double(size) / 1_048_576
            return String(format: "%.1f MB", mb)
        }
    }
}

struct ModelManagerView: View {
    @Binding var modelPath: String
    @Binding var mmprojPath: String

    @State private var models: [ModelFile] = []
    @State private var showFileImporter = false
    @State private var importType: ModelFile.ModelType = .gguf
    @State private var importAlert = false
    @State private var importMessage = ""

    var body: some View {
        NavigationView {
            List {
                // 当前配置摘要
                Section(header: Text("当前配置")) {
                    HStack {
                        Text("主模型")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(modelFileName(from: modelPath))
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    HStack {
                        Text("投影模型")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(modelFileName(from: mmprojPath))
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                // 已导入模型列表
                Section(header: Text("已导入模型 (\(models.count))")) {
                    if models.isEmpty {
                        Text("暂无模型，点击下方按钮导入")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(models) { model in
                            ModelRow(model: model, isSelected: isSelected(model))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectModel(model)
                                }
                        }
                        .onDelete(perform: deleteModel)
                    }
                }

                // 导入按钮
                Section {
                    Button(action: { importType = .gguf; showFileImporter = true }) {
                        Label("导入 GGUF 模型", systemImage: "square.and.arrow.down")
                    }
                    Button(action: { importType = .mmproj; showFileImporter = true }) {
                        Label("导入 MMProj 投影模型", systemImage: "square.and.arrow.down.on.square")
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("模型管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshModelList) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [UTType(filenameExtension: "gguf") ?? UTType.data],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .alert("导入结果", isPresented: $importAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(importMessage)
            }
            .onAppear {
                refreshModelList()
            }
        }
    }

    // MARK: - Helpers

    private func modelFileName(from path: String) -> String {
        let name = (path as NSString).lastPathComponent
        return name.isEmpty ? "未选择" : name
    }

    private func isSelected(_ model: ModelFile) -> Bool {
        if model.type == .gguf {
            return model.path == modelPath
        } else {
            return model.path == mmprojPath
        }
    }

    private func selectModel(_ model: ModelFile) {
        if model.type == .gguf {
            modelPath = model.path
        } else {
            mmprojPath = model.path
        }
    }

    private func refreshModelList() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        guard let files = try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else {
            models = []
            return
        }

        models = files.compactMap { url in
            let name = url.lastPathComponent.lowercased()
            let type: ModelFile.ModelType?
            if name.hasSuffix(".gguf") {
                if name.contains("mmproj") {
                    type = .mmproj
                } else {
                    type = .gguf
                }
            } else {
                return nil
            }

            guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
            let size = attrs[.size] as? Int64 ?? 0
            let modified = attrs[.modificationDate] as? Date ?? Date()

            return ModelFile(name: url.lastPathComponent, path: url.path, size: size, type: type!, modified: modified)
        }.sorted { $0.modified > $1.modified }
    }

    private func deleteModel(at offsets: IndexSet) {
        for index in offsets {
            let model = models[index]
            try? FileManager.default.removeItem(atPath: model.path)
        }
        refreshModelList()
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let sourceURL = urls.first else { return }

            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destURL = docs.appendingPathComponent(sourceURL.lastPathComponent)

            do {
                // 安全访问：先启动安全作用域
                guard sourceURL.startAccessingSecurityScopedResource() else {
                    importMessage = "无法访问文件"
                    importAlert = true
                    return
                }
                defer { sourceURL.stopAccessingSecurityScopedResource() }

                // 如果目标已存在，先删除
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destURL)

                if importType == .gguf {
                    modelPath = destURL.path
                } else {
                    mmprojPath = destURL.path
                }

                importMessage = "导入成功: \(destURL.lastPathComponent)"
                refreshModelList()

            } catch {
                importMessage = "导入失败: \(error.localizedDescription)"
            }
            importAlert = true

        case .failure(let error):
            importMessage = "选择文件失败: \(error.localizedDescription)"
            importAlert = true
        }
    }
}

// MARK: - Model Row

struct ModelRow: View {
    let model: ModelFile
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(model.type.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(model.type == .gguf ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
                        .foregroundColor(model.type == .gguf ? .blue : .orange)
                        .cornerRadius(4)
                    Text(model.sizeText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}
