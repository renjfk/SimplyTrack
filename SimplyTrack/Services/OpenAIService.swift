//
//  OpenAIService.swift
//  SimplyTrack
//
//  OpenAI-compatible API client for generating usage summary notifications.
//  Supports configurable endpoints to work with OpenAI, Azure OpenAI, or other compatible services.
//

import Foundation

// MARK: - Data Transfer Objects

/// Represents a single message in an OpenAI chat completion request.
/// Used to structure conversation context for the AI model.
struct OpenAIChatMessage: Codable {
    /// Role of the message sender (e.g., "user", "assistant", "system")
    let role: String

    /// Content of the message
    let content: String
}

/// Request payload for OpenAI chat completions API.
/// Contains all parameters needed to generate AI responses.
struct OpenAIChatRequest: Codable {
    /// AI model to use for generation (e.g., "gpt-3.5-turbo", "gpt-4")
    let model: String

    /// Array of messages forming the conversation context
    let messages: [OpenAIChatMessage]

    /// Controls randomness in response generation (0.0-2.0)
    let temperature: Double?

    /// Maximum number of tokens to generate in response
    let maxTokens: Int?

    /// Chat template kwargs for OpenAI-compatible providers that support them
    let chatTemplateKwargs: [String: OpenAIJSONValue]?

    /// Reasoning effort for OpenAI-compatible providers that support it
    let reasoningEffort: String?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
        case chatTemplateKwargs = "chat_template_kwargs"
        case reasoningEffort = "reasoning_effort"
    }
}

/// Generic JSON value used for provider-specific OpenAI-compatible request options.
enum OpenAIJSONValue: Codable, Equatable {
    case array([OpenAIJSONValue])
    case bool(Bool)
    case null
    case number(Double)
    case object([String: OpenAIJSONValue])
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([OpenAIJSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: OpenAIJSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .array(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        case .number(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
}

/// Represents a single response choice from the OpenAI API.
/// The API can return multiple choices, but typically only one is used.
struct OpenAIChatChoice: Codable {
    /// Index of this choice in the response array
    let index: Int

    /// The generated message content
    let message: OpenAIChatMessage

    /// Reason why generation stopped (e.g., "stop", "length", "content_filter")
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

/// Token usage information for the API request.
/// Used for billing and monitoring API consumption.
struct OpenAIChatUsage: Codable {
    /// Number of tokens in the input prompt
    let promptTokens: Int

    /// Number of tokens in the generated completion
    let completionTokens: Int

    /// Total tokens used (prompt + completion)
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

/// Complete response from the OpenAI chat completions API.
/// Contains generated content, usage statistics, and metadata.
struct OpenAIChatResponse: Codable {
    /// Unique identifier for this API request
    let id: String

    /// Response object type (always "chat.completion")
    let object: String

    /// Unix timestamp when the response was created
    let created: Int

    /// Model used to generate the response
    let model: String

    /// Array of generated response choices
    let choices: [OpenAIChatChoice]

    /// Token usage statistics for billing
    let usage: OpenAIChatUsage?
}

/// Errors that can occur during OpenAI API communication.
/// Covers network issues, authentication problems, and response parsing failures.
enum OpenAIError: LocalizedError {
    case invalidURL
    case noAPIKey
    case invalidResponse
    case httpError(Int, String)
    case decodingError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .noAPIKey:
            return "No API key provided"
        case .invalidResponse:
            return "Invalid response from API"
        case .httpError(let code, let message):
            return "HTTP error \(code): \(message)"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

/// Service for communicating with OpenAI-compatible chat completion APIs.
/// Supports configurable endpoints to work with OpenAI, Azure OpenAI, or other compatible services.
/// Used primarily for generating AI-powered usage summaries in daily notifications.
class OpenAIService {
    private let apiURL: String
    private let apiKey: String
    private let session: OpenAIURLSession

    /// Initializes the OpenAI service with custom endpoint and API key.
    /// - Parameters:
    ///   - apiURL: API endpoint URL (defaults to OpenAI's chat completions endpoint)
    ///   - apiKey: Authentication key for the API service
    init(apiURL: String = "https://api.openai.com/v1/chat/completions", apiKey: String, session: OpenAIURLSession = URLSession.shared) {
        self.apiURL = apiURL
        self.apiKey = apiKey
        self.session = session
    }

    /// Generates chat completions using the configured AI model.
    /// Used for creating AI-powered summaries of user activity data.
    /// - Parameters:
    ///   - model: AI model identifier (e.g., "gpt-3.5-turbo", "gpt-4")
    ///   - messages: Conversation context including user prompts and system instructions
    ///   - temperature: Response creativity level (0.0-2.0, higher = more creative)
    ///   - maxTokens: Maximum length of generated response
    /// - Returns: Complete API response with generated content and usage statistics
    /// - Throws: OpenAIError for network, authentication, or parsing failures
    func chatCompletions(
        model: String = "gpt-3.5-turbo",
        messages: [OpenAIChatMessage],
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        chatTemplateKwargs: [String: OpenAIJSONValue]? = nil,
        reasoningEffort: String? = nil
    ) async throws -> OpenAIChatResponse {
        guard let url = URL(string: apiURL) else {
            throw OpenAIError.invalidURL
        }

        let request = OpenAIChatRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
            chatTemplateKwargs: chatTemplateKwargs,
            reasoningEffort: reasoningEffort
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        if !apiKey.isEmpty {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw OpenAIError.networkError(error)
        }

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw OpenAIError.httpError(httpResponse.statusCode, errorMessage)
            }

            do {
                return try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
            } catch {
                throw OpenAIError.decodingError
            }
        } catch let error as OpenAIError {
            throw error
        } catch {
            throw OpenAIError.networkError(error)
        }
    }

    /// Parses optional chat template kwargs JSON from settings.
    static func parseChatTemplateKwargs(_ value: String) throws -> [String: OpenAIJSONValue]? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }

        let data = Data(trimmedValue.utf8)
        return try JSONDecoder().decode([String: OpenAIJSONValue].self, from: data)
    }

    /// Parses optional reasoning effort from settings.
    static func parseReasoningEffort(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    /// Removes reasoning blocks that some self-hosted models include in message content.
    static func stripThinkingContent(from value: String) -> String {
        var strippedValue = value
        let patterns = ["<think>.*?</think>", "<thinking>.*?</thinking>"]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { continue }
            let range = NSRange(strippedValue.startIndex..<strippedValue.endIndex, in: strippedValue)
            strippedValue = regex.stringByReplacingMatches(in: strippedValue, options: [], range: range, withTemplate: "")
        }

        strippedValue = strippedValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if startsWithThinkingMarker(strippedValue) {
            if let extractedFinalSection = extractFinalSection(from: strippedValue) {
                strippedValue = extractedFinalSection
            } else if let quotedSummary = extractLongestQuotedText(from: strippedValue) {
                strippedValue = quotedSummary
            } else if let extractedSentenceLines = extractSentenceLikeLines(from: strippedValue) {
                strippedValue = extractedSentenceLines
            } else {
                strippedValue = ""
            }
        }

        return strippedValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func startsWithThinkingMarker(_ value: String) -> Bool {
        let lowercasedValue = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let prefixes = [
            "thinking process:",
            "thought process:",
            "reasoning:",
            "chain of thought:",
            "here's a thinking process",
            "here’s a thinking process",
            "here is a thinking process",
        ]
        return prefixes.contains { lowercasedValue.hasPrefix($0) }
    }

    private static func extractFinalSection(from value: String) -> String? {
        let markers = ["final answer:", "final:", "summary:", "overview:", "answer:"]
        let lowercasedValue = value.lowercased()

        for marker in markers {
            guard let range = lowercasedValue.range(of: marker) else { continue }
            let extractedValue = String(value[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !extractedValue.isEmpty {
                return extractedValue
            }
        }

        return nil
    }

    private static func extractLongestQuotedText(from value: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"\"([^\"]{20,})\""#, options: [.dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        let matches = regex.matches(in: value, options: [], range: range)

        let candidates = matches.compactMap { match -> String? in
            guard let matchRange = Range(match.range(at: 1), in: value) else { return nil }
            return String(value[matchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return candidates.max { $0.count < $1.count }
    }

    private static func extractSentenceLikeLines(from value: String) -> String? {
        let lines =
            value
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let candidateLines = lines.filter { line in
            if line.hasPrefix("-") || line.hasPrefix("*") || line.hasPrefix("•") {
                return false
            }

            if line.range(of: #"^\d+\."#, options: .regularExpression) != nil {
                return false
            }

            let lowercasedLine = line.lowercased()
            if lowercasedLine.hasPrefix("thinking process") || lowercasedLine.hasPrefix("analyze") || lowercasedLine.hasPrefix("draft") || lowercasedLine.hasPrefix("check constraint")
                || lowercasedLine.hasPrefix("final check")
            {
                return false
            }

            return line.contains(".") || line.contains("!") || line.contains("?")
        }

        let extractedValue = candidateLines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return extractedValue.isEmpty ? nil : extractedValue
    }

}

/// URL session abstraction for testing OpenAI requests without network calls.
protocol OpenAIURLSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: OpenAIURLSession {}
