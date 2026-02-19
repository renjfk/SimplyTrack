//
//  MenuBarManager.swift
//  SimplyTrack
//
//  Handles menu bar status item, popover, and launch at login functionality
//

import AppKit
import Combine
import Foundation
import ServiceManagement
import SwiftData
import SwiftUI

/// Manages the macOS menu bar integration, popover presentation, and visual styling.
/// Handles status item creation, popover lifecycle, and environment-specific icon theming.
/// Coordinates with AppDelegate for popover state management and user interaction.
@MainActor
class MenuBarManager: NSObject, NSPopoverDelegate {
    private let modelContainer: ModelContainer
    private weak var appDelegate: AppDelegate?

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var heightCancellable: AnyCancellable?
    private let heightManager = PopoverHeightManager.shared

    /// Initializes menu bar manager with required dependencies.
    /// - Parameters:
    ///   - modelContainer: SwiftData container for popover views
    ///   - appDelegate: App delegate for state coordination
    init(modelContainer: ModelContainer, appDelegate: AppDelegate) {
        self.modelContainer = modelContainer
        self.appDelegate = appDelegate
        super.init()
    }

    /// Sets up the menu bar status item with appropriate icon and interaction.
    /// Configures environment-specific styling and tooltip text.
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let statusButton = statusItem?.button {
            if let svgData = loadSVGIcon(), let image = NSImage(data: svgData) {
                #if !DEBUG
                    image.isTemplate = true
                #endif
                statusButton.image = image
            } else {
                statusButton.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "SimplyTrack")
            }

            #if DEBUG
                statusButton.toolTip = "SimplyTrack (Debug Mode)"
            #else
                statusButton.toolTip = "SimplyTrack"
            #endif

            statusButton.action = #selector(togglePopover)
            statusButton.target = self
        }

        setupPopover()
    }

    /// Configures the popover window with ContentView and environment objects.
    /// Sets appropriate sizing and behavior for the main app interface.
    /// Observes PopoverHeightManager to animate popover height changes.
    func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 340, height: 600)
        popover?.behavior = .transient
        popover?.animates = false

        popover?.contentViewController = NSHostingController(
            rootView: ContentView()
                .modelContainer(modelContainer)
                .environmentObject(appDelegate!)
        )
        popover?.delegate = self

        // Observe ideal height changes from the SwiftUI content and animate popover resizing
        heightCancellable = heightManager.$idealHeight
            .debounce(for: .milliseconds(16), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.updatePopoverHeight()
            }
    }

    /// Triggers an animated popover resize when the ideal content height changes.
    private func updatePopoverHeight() {
        guard let popover = popover, popover.isShown,
            let contentView = popover.contentViewController?.view,
            let window = contentView.window
        else { return }

        heightManager.resizeWindow(window, contentView: contentView)
    }

    /// Shows or hides the popover window.
    /// Called by AppDelegate and status bar interaction handlers.
    @objc func togglePopover() {
        guard let statusButton = statusItem?.button else { return }

        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: statusButton.bounds, of: statusButton, preferredEdge: .minY)
            }
        }
    }

    private func loadSVGIcon() -> Data? {
        guard let url = Bundle.main.url(forResource: "MenuIcon", withExtension: "svg") else {
            return nil
        }

        guard var svgString = try? String(contentsOf: url) else {
            return nil
        }

        #if DEBUG
            // Make the entire icon yellow for debug builds
            svgString = svgString.replacingOccurrences(of: "stroke:#ffffff", with: "stroke:#ffff00")
        #endif

        return svgString.data(using: .utf8)
    }

    // MARK: - Launch at Login

    /// Checks if the app is currently registered to launch at login.
    /// - Returns: True if launch at login is enabled
    func isLaunchAtLoginEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters the app for launch at login.
    /// Shows error dialog if ServiceManagement operations fail.
    /// - Parameter enabled: Whether to enable or disable launch at login
    func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            appDelegate?.showError("Failed to \(enabled ? "enable" : "disable") launch at login", error: error)
        }
    }

    // MARK: - NSPopoverDelegate

    /// Called when popover is about to be shown.
    /// Updates available screen height, resizes to current ideal height, and posts notification.
    func popoverWillShow(_ notification: Notification) {
        heightManager.updateMaxHeight()
        NotificationCenter.default.post(name: NSNotification.Name("PopoverWillShow"), object: nil)

        // Resize on next run loop tick so the window is fully set up
        DispatchQueue.main.async { [weak self] in
            self?.updatePopoverHeight()
        }
    }

    /// Called when popover is closed.
    /// Posts notification for cleanup.
    func popoverDidClose(_ notification: Notification) {
        NotificationCenter.default.post(name: NSNotification.Name("PopoverDidClose"), object: nil)
    }
}
