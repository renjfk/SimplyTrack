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

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
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

    /// Initializes the OpenAI service with custom endpoint and API key.
    /// - Parameters:
    ///   - apiURL: API endpoint URL (defaults to OpenAI's chat completions endpoint)
    ///   - apiKey: Authentication key for the API service
    init(apiURL: String = "https://api.openai.com/v1/chat/completions", apiKey: String) {
        self.apiURL = apiURL
        self.apiKey = apiKey
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
        maxTokens: Int? = nil
    ) async throws -> OpenAIChatResponse {
        guard let url = URL(string: apiURL) else {
            throw OpenAIError.invalidURL
        }

        let request = OpenAIChatRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw OpenAIError.networkError(error)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

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

}
