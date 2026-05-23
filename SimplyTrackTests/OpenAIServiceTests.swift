//
//  OpenAIServiceTests.swift
//  SimplyTrackTests
//
//  Tests for OpenAI-compatible request encoding and provider-specific options.
//

import Foundation
import Testing

@testable import SimplyTrack

struct OpenAIServiceTests {

    @Test func chatRequestOmitsOptionalProviderFieldsByDefault() throws {
        let request = OpenAIChatRequest(
            model: "test-model",
            messages: [OpenAIChatMessage(role: "user", content: "Hello")],
            temperature: nil,
            maxTokens: nil,
            chatTemplateKwargs: nil,
            reasoningEffort: nil
        )

        let body = try encodedJSONObject(from: request)

        #expect(body["chat_template_kwargs"] == nil)
        #expect(body["reasoning_effort"] == nil)
    }

    @Test func chatRequestEncodesProviderFields() throws {
        let optionalParsedKwargs = try OpenAIService.parseChatTemplateKwargs("{\"enable_thinking\":false,\"top_k\":20}")
        let parsedKwargs = try #require(optionalParsedKwargs)
        let request = OpenAIChatRequest(
            model: "test-model",
            messages: [OpenAIChatMessage(role: "user", content: "Hello")],
            temperature: 0.3,
            maxTokens: 42,
            chatTemplateKwargs: parsedKwargs,
            reasoningEffort: "low"
        )

        let body = try encodedJSONObject(from: request)
        let chatTemplateKwargs = try #require(body["chat_template_kwargs"] as? [String: Any])

        #expect(body["model"] as? String == "test-model")
        #expect(body["temperature"] as? Double == 0.3)
        #expect(body["max_tokens"] as? Int == 42)
        #expect(chatTemplateKwargs["enable_thinking"] as? Bool == false)
        #expect(chatTemplateKwargs["top_k"] as? Double == 20)
        #expect(body["reasoning_effort"] as? String == "low")
    }

    @Test func chatTemplateKwargsParsesNestedJSONValues() throws {
        let optionalParsedKwargs = try OpenAIService.parseChatTemplateKwargs(
            "{\"enabled\":true,\"name\":\"qwen\",\"items\":[1,\"two\",null],\"nested\":{\"value\":3.5}}"
        )
        let parsedKwargs = try #require(optionalParsedKwargs)

        #expect(parsedKwargs["enabled"] == .bool(true))
        #expect(parsedKwargs["name"] == .string("qwen"))
        #expect(parsedKwargs["items"] == .array([.number(1), .string("two"), .null]))
        #expect(parsedKwargs["nested"] == .object(["value": .number(3.5)]))
    }

    @Test func emptyProviderOptionsParseAsNil() throws {
        let parsedKwargs = try OpenAIService.parseChatTemplateKwargs("   ")
        let parsedReasoningEffort = OpenAIService.parseReasoningEffort("   ")

        #expect(parsedKwargs == nil)
        #expect(parsedReasoningEffort == nil)
    }

    @Test func reasoningEffortTrimsWhitespace() {
        let parsedReasoningEffort = OpenAIService.parseReasoningEffort("  medium  ")

        #expect(parsedReasoningEffort == "medium")
    }

    @Test func invalidChatTemplateKwargsThrows() {
        #expect(throws: DecodingError.self) {
            _ = try OpenAIService.parseChatTemplateKwargs("not-json")
        }
    }

    @Test func stripsThinkBlocksFromResponseContent() {
        let content = """
            <think>
            I should reason privately.
            </think>

            You used Xcode most yesterday.
            """

        let strippedContent = OpenAIService.stripThinkingContent(from: content)

        #expect(strippedContent == "You used Xcode most yesterday.")
    }

    @Test func stripsThinkingBlocksCaseInsensitively() {
        let content = "Before <Thinking>hidden</Thinking> after"

        let strippedContent = OpenAIService.stripThinkingContent(from: content)

        #expect(strippedContent == "Before  after")
    }

    @Test func extractsQuotedFinalAnswerFromThinkingProcess() {
        let content = """
            Thinking Process:
            1. Analyze the input.
            2. Draft a response.

            \"You spent most of your time in Xcode, with GitHub and Apple's developer docs supporting that work.\"
            """

        let strippedContent = OpenAIService.stripThinkingContent(from: content)

        #expect(strippedContent == "You spent most of your time in Xcode, with GitHub and Apple's developer docs supporting that work.")
    }

    @Test func extractsFinalAnswerSectionFromThinkingProcess() {
        let content = """
            Here's a thinking process:
            1. Review activity.
            2. Decide on tone.

            Final Answer:
            You spent most of your tracked time coding in Xcode and reviewing development resources in Safari.
            """

        let strippedContent = OpenAIService.stripThinkingContent(from: content)

        #expect(strippedContent == "You spent most of your tracked time coding in Xcode and reviewing development resources in Safari.")
    }

    @Test func stripsReasoningOnlyResponseToEmptyString() {
        let content = """
            Here’s a thinking process:

            1. **Analyze User Input:**
            - **Output Format:** Concise daily summary notification
            - **Length:** 100-150 characters MAX
            - **Style:** Friendly tone
            """

        let strippedContent = OpenAIService.stripThinkingContent(from: content)

        #expect(strippedContent.isEmpty)
    }

    @Test func chatCompletionsSendsExpectedRequestAndDecodesResponse() async throws {
        let session = MockOpenAIURLSession(
            data: successResponseData,
            response: httpResponse(statusCode: 200)
        )
        let service = OpenAIService(apiURL: "https://example.com/v1/chat/completions", apiKey: "secret", session: session)
        let chatTemplateKwargs = try OpenAIService.parseChatTemplateKwargs("{\"enable_thinking\":false}")

        let response = try await service.chatCompletions(
            model: "qwen",
            messages: [OpenAIChatMessage(role: "user", content: "Hello")],
            temperature: 0.7,
            maxTokens: 20,
            chatTemplateKwargs: chatTemplateKwargs,
            reasoningEffort: "low"
        )

        let request = try #require(session.request)
        let body = try encodedJSONObject(from: try #require(request.httpBody))
        let messages = try #require(body["messages"] as? [[String: String]])
        let sentKwargs = try #require(body["chat_template_kwargs"] as? [String: Any])

        #expect(request.url?.absoluteString == "https://example.com/v1/chat/completions")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(body["model"] as? String == "qwen")
        #expect(messages == [["role": "user", "content": "Hello"]])
        #expect(body["temperature"] as? Double == 0.7)
        #expect(body["max_tokens"] as? Int == 20)
        #expect(sentKwargs["enable_thinking"] as? Bool == false)
        #expect(body["reasoning_effort"] as? String == "low")
        #expect(response.id == "chatcmpl-test")
        #expect(response.choices.first?.message.content == "Hi")
        #expect(response.usage?.totalTokens == 3)
    }

    @Test func chatCompletionsOmitsAuthorizationHeaderWhenAPIKeyIsEmpty() async throws {
        let session = MockOpenAIURLSession(
            data: successResponseData,
            response: httpResponse(statusCode: 200)
        )
        let service = OpenAIService(apiURL: "https://example.com/v1/chat/completions", apiKey: "", session: session)

        _ = try await service.chatCompletions(
            model: "qwen",
            messages: [OpenAIChatMessage(role: "user", content: "Hello")]
        )

        let request = try #require(session.request)

        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test func chatCompletionsThrowsInvalidURL() async throws {
        let service = OpenAIService(apiURL: "http://[::1", apiKey: "secret", session: MockOpenAIURLSession())

        do {
            _ = try await service.chatCompletions(messages: [])
            Issue.record("Expected invalidURL error")
        } catch OpenAIError.invalidURL {
        } catch {
            Issue.record("Expected invalidURL error, got \(error)")
        }
    }

    @Test func chatCompletionsThrowsInvalidResponseForNonHTTPResponse() async throws {
        let session = MockOpenAIURLSession(
            data: Data(),
            response: URLResponse(url: validURL, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        )
        let service = OpenAIService(apiURL: validURL.absoluteString, apiKey: "secret", session: session)

        do {
            _ = try await service.chatCompletions(messages: [])
            Issue.record("Expected invalidResponse error")
        } catch OpenAIError.invalidResponse {
        } catch {
            Issue.record("Expected invalidResponse error, got \(error)")
        }
    }

    @Test func chatCompletionsThrowsHTTPErrorWithBodyMessage() async throws {
        let session = MockOpenAIURLSession(
            data: Data("bad request".utf8),
            response: httpResponse(statusCode: 400)
        )
        let service = OpenAIService(apiURL: validURL.absoluteString, apiKey: "secret", session: session)

        do {
            _ = try await service.chatCompletions(messages: [])
            Issue.record("Expected httpError")
        } catch OpenAIError.httpError(let code, let message) {
            #expect(code == 400)
            #expect(message == "bad request")
        } catch {
            Issue.record("Expected httpError, got \(error)")
        }
    }

    @Test func chatCompletionsThrowsDecodingErrorForInvalidSuccessBody() async throws {
        let session = MockOpenAIURLSession(
            data: Data("{}".utf8),
            response: httpResponse(statusCode: 200)
        )
        let service = OpenAIService(apiURL: validURL.absoluteString, apiKey: "secret", session: session)

        do {
            _ = try await service.chatCompletions(messages: [])
            Issue.record("Expected decodingError")
        } catch OpenAIError.decodingError {
        } catch {
            Issue.record("Expected decodingError, got \(error)")
        }
    }

    @Test func chatCompletionsThrowsNetworkError() async throws {
        let session = MockOpenAIURLSession(error: URLError(.notConnectedToInternet))
        let service = OpenAIService(apiURL: validURL.absoluteString, apiKey: "secret", session: session)

        do {
            _ = try await service.chatCompletions(messages: [])
            Issue.record("Expected networkError")
        } catch OpenAIError.networkError(let error) {
            #expect((error as? URLError)?.code == .notConnectedToInternet)
        } catch {
            Issue.record("Expected networkError, got \(error)")
        }
    }

    private var validURL: URL {
        URL(string: "https://example.com/v1/chat/completions")!
    }

    private var successResponseData: Data {
        Data(
            """
            {
              "id": "chatcmpl-test",
              "object": "chat.completion",
              "created": 123,
              "model": "qwen",
              "choices": [
                {
                  "index": 0,
                  "message": {"role": "assistant", "content": "Hi"},
                  "finish_reason": "stop"
                }
              ],
              "usage": {"prompt_tokens": 1, "completion_tokens": 2, "total_tokens": 3}
            }
            """.utf8
        )
    }

    private func encodedJSONObject<T: Encodable>(from value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try encodedJSONObject(from: data)
    }

    private func encodedJSONObject(from data: Data) throws -> [String: Any] {
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func httpResponse(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: validURL, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }

}

private final class MockOpenAIURLSession: OpenAIURLSession {
    private let data: Data
    private let response: URLResponse
    private let error: Error?

    private(set) var request: URLRequest?

    init(
        data: Data = Data(),
        response: URLResponse = URLResponse(url: URL(string: "https://example.com")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil),
        error: Error? = nil
    ) {
        self.data = data
        self.response = response
        self.error = error
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        self.request = request

        if let error {
            throw error
        }

        return (data, response)
    }
}
