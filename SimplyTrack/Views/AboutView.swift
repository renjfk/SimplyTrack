//
//  AboutView.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 04.09.2025.
//

import SwiftUI
import AppKit

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            // App Icon
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 64, height: 64)
            }
            
            // App Name and Version
            VStack(spacing: 4) {
                Text("SimplyTrack")
                    .font(.title2)
                    .fontWeight(.medium)
                
                if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                   let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                    Text("Version \(version) (\(build))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Description
            Text("Automatic time tracking for macOS")
                .font(.body)
                .foregroundColor(.secondary)
            
            Divider()
            
            // Copyright and License
            VStack(spacing: 8) {
                Text("Copyright © 2025 Soner Köksal")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Licensed under MIT License")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    if let url = URL(string: "https://github.com/renjfk/SimplyTrack") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("View on GitHub")
                        .font(.caption)
                }
                .buttonStyle(.link)
            }
            
            // Close Button
            HStack {
                Spacer()
                Button("OK") {
                    if let window = NSApp.keyWindow {
                        window.close()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 280)
    }
}

class AboutWindowController: NSWindowController {
    static private var sharedController: AboutWindowController?
    
    static func show() {
        if sharedController?.window?.isVisible == true {
            sharedController?.window?.makeKeyAndOrderFront(nil)
            return
        }
        
        let aboutView = AboutView()
        let hostingController = NSHostingController(rootView: aboutView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.contentViewController = hostingController
        window.title = "About SimplyTrack"
        window.center()
        
        let controller = AboutWindowController(window: window)
        window.delegate = controller
        sharedController = controller
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    override init(window: NSWindow?) {
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension AboutWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        AboutWindowController.sharedController = nil
    }
}
