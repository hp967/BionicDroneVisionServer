//
//  APIModels.swift
//  OpenAI-compatible API 数据结构
//

import Foundation

// MARK: - Request

struct ChatCompletionRequest: Codable {
    let model: String?
    let messages: [Message]
    let temperature: Double?
    let max_tokens: Int?

    struct Message: Codable {
        let role: String
        let content: ContentUnion
    }

    enum ContentUnion: Codable {
        case text(String)
        case array([ContentPart])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) {
                self = .text(text)
            } else if let array = try? container.decode([ContentPart].self) {
                self = .array(array)
            } else {
                throw DecodingError.typeMismatch(ContentUnion.self, DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected String or Array"
                ))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let text): try container.encode(text)
            case .array(let array): try container.encode(array)
            }
        }
    }

    struct ContentPart: Codable {
        let type: String
        let text: String?
        let image_url: ImageURL?
    }

    struct ImageURL: Codable {
        let url: String
    }
}

// MARK: - Response

struct ChatCompletionResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]

    struct Choice: Codable {
        let index: Int
        let message: Message
        let finish_reason: String

        struct Message: Codable {
            let role: String
            let content: String
        }
    }
}

// MARK: - Extract image from request

extension ChatCompletionRequest {
    /// 从多模态消息中提取 base64 图片数据和文本 prompt
    func extractImageAndPrompt() -> (imageBase64: String?, prompt: String) {
        var promptText = ""
        var imageB64: String?

        for msg in messages where msg.role == "user" {
            switch msg.content {
            case .text(let text):
                promptText += text
            case .array(let parts):
                for part in parts {
                    if part.type == "text", let t = part.text {
                        promptText += t
                    } else if part.type == "image_url", let url = part.image_url?.url {
                        // data:image/jpeg;base64,/9j/4AAQ...
                        if let commaRange = url.range(of: ",") {
                            imageB64 = String(url[commaRange.upperBound...])
                        }
                    }
                }
            }
        }

        return (imageB64, promptText)
    }
}
