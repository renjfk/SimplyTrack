//
//  IconView.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 04.09.2025.
//

import SwiftUI
import AppKit

/// Displays app and website icons with fallback generation for missing icons.
/// Supports both cached icon data and automatic letter-based fallback icons.
/// Applies appropriate styling (rounded rectangle for apps, circle for websites).
struct IconView: View {
    /// Type of icon to display with associated data
    enum IconType {
        /// Application icon with bundle identifier and optional cached data
        case app(identifier: String, iconData: Data?)
        /// Website icon with domain and optional favicon data
        case website(domain: String, iconData: Data?)
    }
    
    /// Type of icon to display
    let type: IconType
    /// Size of the icon in points
    let size: CGFloat
    
    private var icon: NSImage? {
        switch type {
        case .app(_, let iconData), .website(_, let iconData):
            if let iconData = iconData {
                return NSImage(data: iconData)
            }
            return nil
        }
    }
    
    /// Creates an icon view with specified type and size
    /// - Parameters:
    ///   - type: Icon type (app or website) with associated data
    ///   - size: Icon size in points (default: 25)
    init(type: IconType, size: CGFloat = 25) {
        self.type = type
        self.size = size
    }
    
    var body: some View {
        Group {
            if let icon = icon {
                Image(nsImage: icon)
                    .antialiased(true)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(iconShape)
            } else {
                // Letter fallback
                Image(nsImage: createLetterIcon())
                    .antialiased(true)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(iconShape)
            }
        }
        .frame(width: size, height: size)
    }
    
    private var iconShape: some Shape {
        switch type {
        case .app:
            return AnyShape(RoundedRectangle(cornerRadius: size * 0.12))
        case .website:
            return AnyShape(Circle())
        }
    }
    
    
    private func createLetterIcon() -> NSImage {
        let (name, backgroundColor) = switch type {
        case .app(let identifier, _):
            (identifier.components(separatedBy: ".").last ?? "App", colorForString(identifier))
        case .website(let domain, _):
            (domain, colorForString(domain))
        }
        
        let letter = String(name.prefix(1)).uppercased()
        let iconSize = NSSize(width: size, height: size)
        
        let image = NSImage(size: iconSize)
        image.lockFocus()
        
        // Draw background
        backgroundColor.setFill()
        let rect = NSRect(origin: .zero, size: iconSize)
        let path = NSBezierPath(rect: rect)
        
        switch type {
        case .app:
            path.appendRoundedRect(rect, xRadius: size * 0.12, yRadius: size * 0.12)
        case .website:
            path.appendOval(in: rect)
        }
        
        path.fill()
        
        // Draw letter
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size * 0.4, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        
        let attributedString = NSAttributedString(string: letter, attributes: attributes)
        let textSize = attributedString.size()
        let textRect = NSRect(
            x: (size - textSize.width) / 2,
            y: (size - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        attributedString.draw(in: textRect)
        image.unlockFocus()
        
        return image
    }
    
    private func colorForString(_ string: String) -> NSColor {
        let colors: [NSColor] = [
            NSColor(red: 0.29, green: 0.56, blue: 0.89, alpha: 1), // Blue
            NSColor(red: 0.49, green: 0.82, blue: 0.13, alpha: 1), // Green
            NSColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 1), // Orange
            NSColor(red: 0.91, green: 0.30, blue: 0.24, alpha: 1), // Red
            NSColor(red: 0.61, green: 0.35, blue: 0.71, alpha: 1), // Purple
            NSColor(red: 0.20, green: 0.67, blue: 0.86, alpha: 1), // Cyan
            NSColor(red: 1.00, green: 0.58, blue: 0.00, alpha: 1), // Deep Orange
            NSColor(red: 0.40, green: 0.23, blue: 0.72, alpha: 1)  // Deep Purple
        ]
        
        let hash = string.hash
        let index = abs(hash) % colors.count
        return colors[index]
    }
}

/// Type-erased shape wrapper for dynamic shape selection
struct AnyShape: Shape {
    private let _path: @Sendable (CGRect) -> Path
    
    /// Creates type-erased shape from any concrete shape
    /// - Parameter shape: Concrete shape to wrap
    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}