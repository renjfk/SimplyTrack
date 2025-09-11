//
//  UsageListView.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 04.09.2025.
//

import SwiftUI

enum UsageListType {
    case apps
    case websites
    
    var title: String {
        switch self {
        case .apps: return "Apps"
        case .websites: return "Websites"
        }
    }
    
    var iconType: (String, String, Data?) -> IconView.IconType {
        switch self {
        case .apps:
            return { identifier, _, iconData in .app(identifier: identifier, iconData: iconData) }
        case .websites:
            return { _, name, iconData in .website(domain: name, iconData: iconData) }
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .apps: return 25
        case .websites: return 20
        }
    }
}

/// Displays a list of apps or websites with usage statistics and icons.
/// Supports expandable/collapsible view with animated transitions.
/// Shows top items sorted by usage time with formatted durations.
struct UsageListView: View {
    let type: UsageListType
    /// Array of item data sorted by usage time
    let items: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)]
    /// Controls whether to show all items or just top 5
    @Binding var showAllItems: Bool
    
    private var displayedItems: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)] {
        showAllItems ? items : Array(items.prefix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(type.title)
                    .font(.headline)
                Spacer()
                if items.count > 5 {
                    Button(showAllItems ? "Show less" : "Show more") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAllItems.toggle()
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }

            VStack(spacing: 8) {
                ForEach(Array(displayedItems.enumerated()), id: \.element.identifier) { index, item in
                    HStack {
                        IconView(type: type.iconType(item.identifier, item.name, item.iconData), size: type.iconSize)

                        Text(item.name)

                        Spacer()

                        Text(item.totalTime.formattedDuration)
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}