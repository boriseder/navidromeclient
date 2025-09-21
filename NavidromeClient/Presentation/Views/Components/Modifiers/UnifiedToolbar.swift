//
//  ToolbarConfigurable.swift
//  NavidromeClient
//
//  Created by Boris Eder on 18.09.25.
//


//
//  UnifiedToolbar.swift - COMPLETE Toolbar System
//  NavidromeClient
//
//   INTEGRATES: Existing AccountToolbarModifier functionality
//   REPLACES: All existing toolbar patterns
//   SUSTAINABLE: Single source of truth for all toolbars
//

import SwiftUI

// MARK: - 1. Toolbar Configuration Protocol
protocol ToolbarConfigurable {
    var toolbarConfig: ToolbarConfiguration { get }
}

// MARK: - 2. Unified Toolbar Configuration
struct ToolbarConfiguration {
    let leftItems: [ToolbarElement]
    let rightItems: [ToolbarElement]
    let title: String?
    let displayMode: NavigationBarItem.TitleDisplayMode
    let showSettings: Bool //  INTEGRATES AccountToolbarModifier
    
    init(
        leftItems: [ToolbarElement] = [],
        rightItems: [ToolbarElement] = [],
        title: String? = nil,
        displayMode: NavigationBarItem.TitleDisplayMode = .automatic,
        showSettings: Bool = true //  DEFAULT: Show settings (like AccountToolbarModifier)
    ) {
        self.leftItems = leftItems
        self.rightItems = rightItems
        self.title = title
        self.displayMode = displayMode
        self.showSettings = showSettings
    }
    
    static let empty = ToolbarConfiguration()
}

// MARK: - 3. Toolbar Element Types
enum ToolbarElement: Identifiable {
    //  EXISTING: From analysis of your current toolbars
    case settings // Now handled by showSettings flag
    case refresh(action: () async -> Void)
    case offlineToggle(isOffline: Bool, toggle: () -> Void)
    case sort(current: String, options: [SortOption], onSelect: (SortOption) -> Void)
    case search
    case custom(icon: String, action: () -> Void)
    case menu(icon: String, items: [MenuAction])
    case asyncCustom(icon: String, action: () async -> Void) // For loading states
    
    var id: String {
        switch self {
        case .settings: return "settings"
        case .refresh: return "refresh"
        case .offlineToggle: return "offline"
        case .sort: return "sort"
        case .custom(let icon, _): return "custom_\(icon)"
        case .search: return "search"
        case .menu(let icon, _): return "menu_\(icon)"
        case .asyncCustom(let icon, _): return "async_\(icon)"
        }
    }
}

struct SortOption: Identifiable, Hashable {
    let id: String
    let displayName: String
    let icon: String
    
    init(id: String, displayName: String, icon: String) {
        self.id = id
        self.displayName = displayName
        self.icon = icon
    }
}

struct MenuAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String?
    let isDestructive: Bool
    let action: () -> Void
    
    init(title: String, icon: String? = nil, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isDestructive = isDestructive
        self.action = action
    }
}

// MARK: - 4. Unified Toolbar ViewModifier
struct UnifiedToolbar: ViewModifier {
    let config: ToolbarConfiguration
    @EnvironmentObject private var offlineManager: OfflineManager
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    
    func body(content: Content) -> some View {
        content
            .navigationTitle(config.title ?? "")
            .navigationBarTitleDisplayMode(config.displayMode)
            .toolbar {
                // Left Items
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    ForEach(config.leftItems) { item in
                        toolbarButton(for: item)
                    }
                }
                
                // Right Items + Settings
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    ForEach(config.rightItems) { item in
                        toolbarButton(for: item)
                    }
                    
                    //  INTEGRATES AccountToolbarModifier: Always show settings unless disabled
                    if config.showSettings {
                        SettingsButton()
                    }
                }
            }
    }
    
    @ViewBuilder
    private func toolbarButton(for element: ToolbarElement) -> some View {
        switch element {
        case .refresh(let action):
            AsyncToolbarButton(icon: "arrow.clockwise", action: action)
            
        case .offlineToggle(let isOffline, let toggle):
            OfflineToggleButton(isOffline: isOffline, toggle: toggle)
            
        case .sort(let current, let options, let onSelect):
            SortMenuButton(current: current, options: options, onSelect: onSelect)
            
        case .custom(let icon, let action):
            Button(action: action) {
                Image(systemName: icon)
                    .foregroundColor(.primary)
            }
            
        case .asyncCustom(let icon, let action):
            AsyncToolbarButton(icon: icon, action: action)
            
        case .menu(let icon, let items):
            MenuToolbarButton(icon: icon, items: items)
            
        case .settings:
            SettingsButton() // Explicit settings button (usually handled by showSettings)
            
        case .search:
            EmptyView() // Search is handled by .searchable modifier
        }
    }
}

// MARK: - 5. Specialized Toolbar Buttons

private struct AsyncToolbarButton: View {
    let icon: String
    let action: () async -> Void
    @State private var isLoading = false
    
    var body: some View {
        Button {
            Task {
                isLoading = true
                await action()
                isLoading = false
            }
        } label: {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: icon)
                    .foregroundColor(.primary)
            }
        }
        .disabled(isLoading)
    }
}

private struct OfflineToggleButton: View {
    let isOffline: Bool
    let toggle: () -> Void
    
    var body: some View {
        Button(action: toggle) {
            HStack(spacing: DSLayout.tightGap) {
                Image(systemName: isOffline ? "icloud.slash" : "icloud")
                    .font(DSText.metadata)
                Text(isOffline ? "Offline" : "All")
                    .font(DSText.metadata)
            }
            .foregroundStyle(isOffline ? DSColor.warning : DSColor.accent)
            .padding(.horizontal, DSLayout.elementPadding)
            .padding(.vertical, DSLayout.tightPadding)
            .background(
                Capsule()
                    .fill((isOffline ? DSColor.warning : DSColor.accent).opacity(0.1))
            )
        }
    }
}

private struct SortMenuButton: View {
    let current: String
    let options: [SortOption]
    let onSelect: (SortOption) -> Void
    
    private var currentOption: SortOption? {
        options.first { $0.id == current }
    }
    
    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    onSelect(option)
                } label: {
                    HStack {
                        if let icon = option.icon.isEmpty ? nil : option.icon {
                            Image(systemName: icon)
                        }
                        Text(option.displayName)
                        if option.id == current {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: currentOption?.icon ?? "line.3.horizontal.decrease")
                .foregroundColor(.primary)
        }
    }
}

private struct MenuToolbarButton: View {
    let icon: String
    let items: [MenuAction]
    
    var body: some View {
        Menu {
            ForEach(items) { item in
                Button(role: item.isDestructive ? .destructive : nil) {
                    item.action()
                } label: {
                    HStack {
                        if let icon = item.icon {
                            Image(systemName: icon)
                        }
                        Text(item.title)
                    }
                }
            }
        } label: {
            Image(systemName: icon)
                .foregroundColor(.primary)
        }
    }
}

//  REPLACES AccountToolbarModifier functionality
private struct SettingsButton: View {
    var body: some View {
        NavigationLink {
            SettingsView()
        } label: {
            Image(systemName: "gearshape.fill")
                .foregroundColor(.primary)
        }
    }
}

// MARK: - 6. View Extensions
extension View {
    func unifiedToolbar(_ config: ToolbarConfiguration) -> some View {
        self.modifier(UnifiedToolbar(config: config))
    }
    
    
    //  NEW: Convenience for no toolbar
    func noToolbar() -> some View {
        self.unifiedToolbar(ToolbarConfiguration(showSettings: false))
    }
}

// MARK: - 7. Common Toolbar Configurations

extension ToolbarConfiguration {
    
    //  REPLACES: Most AlbumsView/ArtistsView/GenreView toolbars
    static func library(
        title: String,
        isOffline: Bool,
        onRefresh: @escaping () async -> Void,
        onToggleOffline: @escaping () -> Void
    ) -> ToolbarConfiguration {
        ToolbarConfiguration(
            //leftItems: [.refresh(action: onRefresh)],
            leftItems: [],
            //rightItems: [.offlineToggle(isOffline: isOffline, toggle: onToggleOffline)],
            rightItems: [],
            title: title,
            displayMode: .large,
            showSettings: true
        )
    }
    
    //  COVERS: AlbumsView with sorting
    static func libraryWithSort<T>(
        title: String,
        isOffline: Bool,
        currentSort: T,
        sortOptions: [T],
        onRefresh: @escaping () async -> Void,
        onToggleOffline: @escaping () -> Void,
        onSort: @escaping (T) -> Void
    ) -> ToolbarConfiguration where T: RawRepresentable, T.RawValue == String, T: CaseIterable, T: Hashable {
        
        let options = sortOptions.map { option in
            SortOption(
                id: option.rawValue,
                displayName: getSortDisplayName(option),
                icon: getSortIcon(option)
            )
        }
        
        return ToolbarConfiguration(
            // leftItems: [.refresh(action: onRefresh)],
           
            //we do not want a refresh => pull to refresh
            // leftItems: [],
            rightItems: [
                .sort(
                    current: currentSort.rawValue,
                    options: options,
                    onSelect: { sortOption in
                        if let option = sortOptions.first(where: { $0.rawValue == sortOption.id }) {
                            onSort(option)
                        }
                    }
                ),
                //.offlineToggle(isOffline: isOffline, toggle: onToggleOffline)
            ],
            title: title,
            displayMode: .large,
            showSettings: true
        )
    }
    
    //  COVERS: Detail views like AlbumDetailView
    static func detail(
        title: String,
        actions: [ToolbarElement] = []
    ) -> ToolbarConfiguration {
        ToolbarConfiguration(
            leftItems: [],
            rightItems: actions,
            title: title,
            displayMode: .inline,
            showSettings: true
        )
    }
    
    //  COVERS: Search views
    static func search() -> ToolbarConfiguration {
        ToolbarConfiguration(
            leftItems: [],
            rightItems: [],
            title: "Search",
            displayMode: .large,
            showSettings: true
        )
    }
    
    //  COVERS: Settings and other modal views
    static func modal(title: String) -> ToolbarConfiguration {
        ToolbarConfiguration(
            leftItems: [],
            rightItems: [],
            title: title,
            displayMode: .inline,
            showSettings: false // No nested settings
        )
    }
}

// MARK: - 8. Sort Configuration Helpers

//  MAPS: ContentService.AlbumSortType to display names
private func getSortDisplayName<T>(_ sortType: T) -> String where T: RawRepresentable, T.RawValue == String {
    // This would need to be implemented based on your actual sort types
    if let albumSort = sortType as? ContentService.AlbumSortType {
        return albumSort.displayName
    }
    
    // Fallback: Use raw value with formatting
    return sortType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
}

private func getSortIcon<T>(_ sortType: T) -> String where T: RawRepresentable, T.RawValue == String {
    // This would need to be implemented based on your actual sort types
    if let albumSort = sortType as? ContentService.AlbumSortType {
        return albumSort.icon
    }
    
    // Fallback icon
    return "line.3.horizontal.decrease"
}

// MARK: - 9. Migration from Existing Patterns

/*
## MIGRATION MAP

### Replace these patterns:

OLD:
```swift
.accountToolbar()
```
NEW:
```swift 
.unifiedToolbar(.empty) // or specific config
```

OLD:
```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        NavigationLink { SettingsView() } label: {
            Image(systemName: "gearshape.fill")
        }
    }
}
```
NEW:
```swift
.unifiedToolbar(ToolbarConfiguration(showSettings: true))
```

OLD (AlbumsView toolbar):
```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) { albumSortMenu }
    ToolbarItem(placement: .navigationBarTrailing) { offlineModeToggle }
    ToolbarItem(placement: .navigationBarLeading) { refreshButton }
}
```
NEW:
```swift
.unifiedToolbar(.libraryWithSort(
    title: "Albums",
    isOffline: isOfflineMode,
    currentSort: selectedAlbumSort,
    sortOptions: ContentService.AlbumSortType.allCases,
    onRefresh: refreshAllData,
    onToggleOffline: toggleOfflineMode,  
    onSort: loadAlbums
))
```
*/
