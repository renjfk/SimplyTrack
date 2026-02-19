//
//  PopoverHeightManager.swift
//  SimplyTrack
//
//  Coordinates popover height between ContentView and MenuBarManager
//

import AppKit
import SwiftUI

/// Observable object shared between ContentView and MenuBarManager to coordinate popover height.
/// ContentView sets the ideal height; MenuBarManager reads it to resize the popover.
@MainActor
class PopoverHeightManager: ObservableObject {
    static let shared = PopoverHeightManager()

    /// The ideal content height as measured by the SwiftUI layout system
    @Published var idealHeight: CGFloat = 0
    /// Maximum available height based on screen size minus menu bar
    @Published var maxAvailableHeight: CGFloat = 800

    /// The actual popover height — the lesser of ideal height and max available height
    var effectiveHeight: CGFloat {
        min(max(idealHeight, 200), maxAvailableHeight)
    }

    /// Whether the content exceeds the available screen space and needs scrolling
    var needsScrolling: Bool {
        idealHeight > maxAvailableHeight
    }

    private init() {}

    /// Updates the max available height based on the screen containing the menu bar.
    func updateMaxHeight() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        // Screen visible frame excludes menu bar and dock
        let visibleHeight = screen.visibleFrame.height
        // Leave 20pt margin from screen edges for the popover arrow and padding
        maxAvailableHeight = visibleHeight - 20
    }

    /// Resizes the popover's backing window with animation to match the ideal content height.
    /// Grows/shrinks upward from the bottom edge so the popover stays anchored to the menu bar icon.
    /// - Parameters:
    ///   - window: The popover's backing NSWindow
    ///   - contentView: The popover's content view, used to calculate chrome offset
    func resizeWindow(_ window: NSWindow, contentView: NSView) {
        updateMaxHeight()
        let newContentHeight = effectiveHeight
        let currentFrame = window.frame

        // The window frame includes popover chrome (arrow, border). Calculate the chrome offset
        // as the difference between the current window height and the content view height.
        let chromeHeight = currentFrame.height - contentView.frame.height
        let newWindowHeight = newContentHeight + chromeHeight

        let heightDelta = newWindowHeight - currentFrame.height
        guard abs(heightDelta) > 1 else { return }

        // Grow/shrink upward: keep the top edge (maxY) fixed, adjust origin.y downward
        var newFrame = currentFrame
        newFrame.size.height = newWindowHeight
        newFrame.origin.y -= heightDelta

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }
    }
}
