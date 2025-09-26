//
//  IconUtils.swift
//  SimplyTrack
//
//  Utility functions for app icon extraction, resizing, and PNG conversion
//

import AppKit
import Foundation

enum IconUtils {

    /// Extracts and converts an app icon to PNG format with 32x32 size
    /// - Parameter app: The running application to extract icon from
    /// - Returns: PNG data of the resized icon, or nil if extraction fails
    static func getAppIconAsPNG(for app: NSRunningApplication) -> Data? {
        guard let icon = app.icon else { return nil }

        // Create a new image with 32x32 size using modern API
        let targetSize = NSSize(width: 32, height: 32)
        let resizedImage = NSImage(size: targetSize, flipped: false) { rect in
            icon.draw(in: rect)
            return true
        }

        // Convert to PNG
        guard let tiffData = resizedImage.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }

    /// Resizes any image to specified dimensions and converts to PNG
    /// - Parameters:
    ///   - image: Source image to resize
    ///   - size: Target size for the resized image
    /// - Returns: PNG data of the resized image, or nil if conversion fails
    static func resizeImageToPNG(_ image: NSImage, targetSize size: NSSize) -> Data? {
        let resizedImage = NSImage(size: size, flipped: false) { rect in
            image.draw(in: rect)
            return true
        }

        guard let tiffData = resizedImage.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }
}
