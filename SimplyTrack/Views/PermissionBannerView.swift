//
//  PermissionBannerView.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 04.09.2025.
//

import SwiftUI

struct PermissionBannerView: View {
    let title: String
    let message: String
    let primaryButtonTitle: String
    let primaryAction: () -> Void
    let dismissAction: (() -> Void)?
    let color: Color
    
    init(
        title: String,
        message: String,
        primaryButtonTitle: String,
        primaryAction: @escaping () -> Void,
        dismissAction: (() -> Void)? = nil,
        color: Color = .red
    ) {
        self.title = title
        self.message = message
        self.primaryButtonTitle = primaryButtonTitle
        self.primaryAction = primaryAction
        self.dismissAction = dismissAction
        self.color = color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
                
                if let dismissAction = dismissAction {
                    Button("Dismiss") {
                        dismissAction()
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Spacer()
                Button(primaryButtonTitle) {
                    primaryAction()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}