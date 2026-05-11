//
//  BrowserSupportTests.swift
//  SimplyTrackTests
//
//  Created by Hermes Agent on 06.05.2026.
//

import Testing

@testable import SimplyTrack

struct BrowserSupportTests {

    @Test func chatGPTAtlasIsRecognizedAsSupportedBrowser() {
        let service = WebTrackingService()

        let browser = service.getBrowser(for: "com.openai.atlas")

        #expect(browser != nil)
        #expect(browser?.bundleId == "com.openai.atlas")
    }

    @Test func chatGPTAtlasWebProcessIsRecognizedAsSupportedBrowser() {
        let service = WebTrackingService()

        let browser = service.getBrowser(for: "com.openai.atlas.web")

        #expect(browser != nil)
        #expect(browser?.bundleId == "com.openai.atlas")
        #expect(browser?.displayName == "ChatGPT Atlas")
    }
}
