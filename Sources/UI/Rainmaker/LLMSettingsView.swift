import SwiftUI

/// AI 引擎设置：多套供应商配置可切换，Key 只进本机钥匙串。
/// 选中「内置台词池」= 不直连（现状）；生成失败运行时自动回退台词池，不打断进程。
struct LLMSettingsView: View {
    @Bindable var llm: LLMSettingsStore
    /// 正在编辑的配置（nil = 无弹窗）。
    @State private var editing: EditingDraft?

    private struct EditingDraft: Identifiable {
        let config: LLMProviderConfig
        let apiKey: String
        let isNew: Bool
        var id: UUID { config.id }
    }

    var body: some View {
        List {
            Section {
                Button {
                    llm.setActive(nil)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("内置台词池")
                                .foregroundStyle(WA.textPrimary)
                            Text("离线确定性脚本，不联网")
                                .font(.footnote)
                                .foregroundStyle(WA.textSecondary)
                        }
                        Spacer()
                        if llm.activeID == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(WA.accent)
                        }
                    }
                }

                ForEach(llm.configs) { config in
                    Button {
                        llm.setActive(config.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(config.name)
                                    .foregroundStyle(WA.textPrimary)
                                Text("\(config.protocolKind.displayName) · \(config.model)")
                                    .font(.footnote)
                                    .foregroundStyle(WA.textSecondary)
                            }
                            Spacer()
                            if llm.activeID == config.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(WA.accent)
                            }
                            Button {
                                editing = EditingDraft(config: config, apiKey: llm.apiKey(for: config.id), isNew: false)
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(WA.accent)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .swipeActions {
                        Button("删除", role: .destructive) {
                            llm.remove(config.id)
                        }
                    }
                }
            } header: {
                Text("对话引擎")
            } footer: {
                Text("选中即生效：NPC 聊天与谈判桌台词改由大模型按人设实时生成。生成失败自动回退内置台词，进程不受影响。")
            }

            Section {
                Menu {
                    ForEach(LLMPreset.allCases) { preset in
                        Button(preset.displayName) {
                            editing = EditingDraft(config: preset.makeConfig(), apiKey: "", isNew: true)
                        }
                    }
                } label: {
                    Label("添加供应商", systemImage: "plus.circle.fill")
                }
            } footer: {
                Text("API Key 只存本机钥匙串，不落存档、不上云。OpenAI 兼容协议可接 DeepSeek、Kimi、通义、智谱、OpenRouter、本机 Ollama 等一切兼容接口。")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("AI 引擎")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { draft in
            NavigationStack {
                LLMProviderEditorView(
                    config: draft.config,
                    apiKey: draft.apiKey,
                    isNew: draft.isNew
                ) { saved, key in
                    llm.upsert(saved, apiKey: key)
                    // 新建即激活：配好就能用，少一步
                    if draft.isNew { llm.setActive(saved.id) }
                }
            }
        }
    }
}

/// 供应商编辑表单：预设字段全可改 + 保存前可测连通。
private struct LLMProviderEditorView: View {
    @State var config: LLMProviderConfig
    @State var apiKey: String
    let isNew: Bool
    let onSave: (LLMProviderConfig, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var testResult: TestResult?
    @State private var testing = false

    private enum TestResult {
        case success(String)
        case failure(String)
    }

    private var canSave: Bool {
        !config.name.trimmingCharacters(in: .whitespaces).isEmpty
            && !config.baseURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !config.model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section("基本") {
                TextField("名称", text: $config.name)
                Picker("协议", selection: $config.protocolKind) {
                    ForEach(LLMProviderConfig.ProtocolKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
            }

            Section {
                TextField("接口地址", text: $config.baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                TextField("模型", text: $config.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("接口")
            } footer: {
                Text(config.protocolKind == .openAICompatible
                     ? "OpenAI 兼容地址一般以 /v1 结尾，客户端自动拼 /chat/completions。"
                     : "只填域名根地址，路径由协议自动拼接。")
            }

            Section {
                SecureField("API Key（本机 Ollama 可留空）", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("凭证")
            } footer: {
                Text("仅存本机钥匙串（ThisDeviceOnly），不参与 iCloud 备份。")
            }

            Section {
                Button {
                    runTest()
                } label: {
                    if testing {
                        HStack {
                            ProgressView()
                            Text("测试中…")
                        }
                    } else {
                        Label("测试连接", systemImage: "bolt.horizontal.circle")
                    }
                }
                .disabled(testing || !canSave)

                switch testResult {
                case let .success(reply):
                    Label(reply, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case let .failure(message):
                    Label(message, systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                        .font(.footnote)
                case nil:
                    EmptyView()
                }
            }
        }
        .navigationTitle(isNew ? "添加供应商" : "编辑供应商")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    onSave(config, apiKey)
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
    }

    private func runTest() {
        testing = true
        testResult = nil
        let config = config
        let apiKey = apiKey
        Task {
            let result = await LLMSettingsStore.testConnection(config: config, apiKey: apiKey)
            switch result {
            case let .success(reply):
                testResult = .success("模型在线：\(reply.prefix(40))")
            case let .failure(error):
                testResult = .failure(error.localizedDescription)
            }
            testing = false
        }
    }
}
