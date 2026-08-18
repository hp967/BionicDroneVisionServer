//
//  LlamaVisionEngine.swift
//  llama.cpp + clip 多模态推理封装
//
//  注意：此实现基于 llama.cpp 的 C API (llama.h + clip.h)
//  如果使用的 llama.cpp 版本较新 (>= b3500) 改用 libmtmd，
//  需要将此文件中的 clip_xxx 调用替换为 mtmd_xxx 调用。
//

import Foundation

enum LlamaError: Error {
    case modelLoadFailed(String)
    case mmprojLoadFailed(String)
    case imageDecodeFailed
    case inferenceFailed(String)
    case contextCreationFailed
}

/// 封装 llama.cpp 视觉推理引擎
final class LlamaVisionEngine {
    private var model: OpaquePointer?      // llama_model*
    private var ctx: OpaquePointer?        // llama_context*
    private var clipCtx: OpaquePointer?    // clip_ctx*
    private var vocab: OpaquePointer?      // llama_vocab* (llama.cpp >= b3600)

    private let nCtx: Int32 = 4096
    private let nThreads: Int32 = 4        // M1 四核

    /// 是否已加载模型
    var isLoaded: Bool {
        model != nil && ctx != nil
    }

    // MARK: - Lifecycle

    init() {}

    deinit {
        unload()
    }

    func unload() {
        if let ctx = ctx {
            llama_free(ctx)
            self.ctx = nil
        }
        if let model = model {
            llama_free_model(model)
            self.model = nil
        }
        if let clipCtx = clipCtx {
            clip_free(clipCtx)
            self.clipCtx = nil
        }
    }

    // MARK: - Load Model

    /// 加载 GGUF 模型和 mmproj 投影模型
    func loadModel(modelPath: String, mmprojPath: String) throws {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw LlamaError.modelLoadFailed("模型文件不存在: \(modelPath)")
        }
        guard FileManager.default.fileExists(atPath: mmprojPath) else {
            throw LlamaError.mmprojLoadFailed("mmproj 文件不存在: \(mmprojPath)")
        }

        // 1. 初始化 llama 后端
        var params = llama_model_default_params()
        params.n_gpu_layers = 99  // 尽可能多 offload 到 Metal GPU

        let cModelPath = modelPath.cString(using: .utf8)!
        guard let model = llama_load_model_from_file(cModelPath, params) else {
            throw LlamaError.modelLoadFailed("llama_load_model_from_file 失败")
        }
        self.model = model

        // 2. 创建上下文
        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = nCtx
        ctxParams.n_threads = nThreads
        ctxParams.n_threads_batch = nThreads

        guard let ctx = llama_new_context_with_model(model, ctxParams) else {
            throw LlamaError.contextCreationFailed
        }
        self.ctx = ctx

        // 保存 vocab 指针供后续使用（避免每次推理重复获取）
        self.vocab = llama_model_get_vocab(model)

        // 3. 加载 clip/mmproj
        let cMmprojPath = mmprojPath.cString(using: .utf8)!
        guard let clipCtx = clip_model_load(cMmprojPath, 1) else {
            throw LlamaError.mmprojLoadFailed("clip_model_load 失败")
        }
        self.clipCtx = clipCtx

        print("[LlamaVisionEngine] 模型加载成功")
        print("  - Model: \(modelPath)")
        print("  - MMProj: \(mmprojPath)")
        print("  - n_gpu_layers: 99 (Metal)")
    }

    // MARK: - Inference

    /// 视觉推理：输入 base64 图片 + 文本 prompt，输出生成的文本
    func infer(imageBase64: String, prompt: String, maxTokens: Int32 = 256) throws -> String {
        guard let model = model, let ctx = ctx, let clipCtx = clipCtx else {
            throw LlamaError.inferenceFailed("模型未加载")
        }

        // 1. 解码 base64 图片
        guard let imageData = Data(base64Encoded: imageBase64, options: .ignoreUnknownCharacters),
              imageData.count > 0 else {
            throw LlamaError.imageDecodeFailed
        }

        // 2. 用 clip 提取图片 embedding
        let imageBytes = [UInt8](imageData)
        let imageEmbed = imageBytes.withUnsafeBufferPointer { ptr in
            llava_image_embed_make_with_bytes(
                clipCtx,
                Int32(nThreads),
                ptr.baseAddress,
                Int32(imageData.count)
            )
        }
        guard let imageEmbed = imageEmbed else {
            throw LlamaError.inferenceFailed("图片 embedding 提取失败")
        }
        defer { llava_image_embed_free(imageEmbed) }

        // 3. Tokenize prompt
        let promptTokens = tokenize(text: prompt, addBos: true)

        // 4. 构造 batch：先放图片 embed，再放 prompt tokens
        let nImageTokens = Int(imageEmbed.n_image_pos)
        let nPromptTokens = promptTokens.count
        let nBatch = nImageTokens + nPromptTokens

        guard nBatch <= Int(nCtx) else {
            throw LlamaError.inferenceFailed("输入长度超过 n_ctx")
        }

        var batch = llama_batch_init(Int32(nBatch), 0, 1)
        defer { llama_batch_free(batch) }

        // 填充图片 embedding
        if let embed = imageEmbed.embed {
            for i in 0..<nImageTokens {
                batch.token[i] = 0  // image tokens 用 0 占位，实际值在 embd 里
                batch.embd[i] = embed.advanced(by: i)
                batch.pos[i] = Int32(i)
                batch.n_seq_id[i] = 1
                batch.seq_id[i]![0] = 0
                batch.logits[i] = 0
            }
        }

        // 填充 prompt tokens
        for i in 0..<nPromptTokens {
            let idx = nImageTokens + i
            batch.token[idx] = promptTokens[i]
            batch.pos[idx] = Int32(idx)
            batch.n_seq_id[idx] = 1
            batch.seq_id[idx]![0] = 0
            batch.logits[idx] = (i == nPromptTokens - 1) ? 1 : 0  // 最后一个 prompt token 要算 logits
        }

        batch.n_tokens = Int32(nBatch)

        // 5. Decode
        if llama_decode(ctx, batch) != 0 {
            throw LlamaError.inferenceFailed("llama_decode 失败")
        }

        // 6. 采样生成
        var result = ""
        var nCur = batch.n_tokens

        guard let vocab = self.vocab else {
            throw LlamaError.inferenceFailed("vocab 未初始化")
        }
        let eosToken = llama_token_eos(vocab)

        var sparams = llama_sampler_chain_default_params()
        let smpl = llama_sampler_chain_init(sparams)
        defer { llama_sampler_free(smpl) }

        llama_sampler_chain_add(smpl, llama_sampler_init_greedy())
        // 也可用 temp sampling：
        // llama_sampler_chain_add(smpl, llama_sampler_init_temp(0.15))
        // llama_sampler_chain_add(smpl, llama_sampler_init_dist(42))

        for _ in 0..<maxTokens {
            guard nCur < nCtx else { break }

            let token = llama_sampler_sample(smpl, ctx, -1)
            if token == eosToken {
                break
            }

            result += tokenToString(token: token)

            // 把生成的 token 喂回模型
            var nextBatch = llama_batch_init(1, 0, 1)
            nextBatch.token[0] = token
            nextBatch.pos[0] = nCur
            nextBatch.n_seq_id[0] = 1
            nextBatch.seq_id[0]![0] = 0
            nextBatch.logits[0] = 1
            nextBatch.n_tokens = 1

            if llama_decode(ctx, nextBatch) != 0 {
                llama_batch_free(nextBatch)
                throw LlamaError.inferenceFailed("decode 生成失败")
            }
            llama_batch_free(nextBatch)

            nCur += 1
        }

        // 清理 kv cache
        llama_kv_cache_clear(ctx)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private func tokenize(text: String, addBos: Bool) -> [llama_token] {
        guard let vocab = self.vocab else { return [] }
        let nTokens = text.utf8.count + (addBos ? 1 : 0)
        var tokens = [llama_token](repeating: 0, count: nTokens)
        let actualCount = llama_tokenize(
            vocab,
            text.cString(using: .utf8),
            Int32(text.utf8.count),
            &tokens,
            Int32(nTokens),
            addBos,
            false
        )
        return Array(tokens.prefix(Int(actualCount)))
    }

    private func tokenToString(token: llama_token) -> String {
        guard let vocab = self.vocab else { return "" }
        guard let cStr = llama_token_get_text(vocab, token) else { return "" }
        return String(cString: cStr)
    }
}
