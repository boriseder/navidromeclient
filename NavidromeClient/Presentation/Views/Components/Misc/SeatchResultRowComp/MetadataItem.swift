//
//  SearchResultRow.swift - UPDATED for CoverArtManager
//  NavidromeClient
//
//   UPDATED: Uses unified CoverArtManager instead of multiple services
//   REACTIVE: Uses centralized image state instead of local @State
//



import SwiftUI


// MARK: - Shared Components (unchanged)

struct MetadataItem: View {
    let icon: String
    let text: String
    let fontSize: Font
    
    init(icon: String, text: String, fontSize: Font = DSText.metadata) {
        self.icon = icon
        self.text = text
        self.fontSize = fontSize
    }
    
    var body: some View {
        HStack(spacing: DSLayout.tightGap) {
            Image(systemName: icon)
                .font(fontSize)
                .foregroundStyle(DSColor.secondary)
            
            Text(text)
                .font(fontSize.weight(.medium))
                .foregroundStyle(DSColor.secondary)
                .lineLimit(1)
        }
    }
}

struct MetadataSeparator: View {
    let fontSize: Font
    
    init(fontSize: Font = DSText.metadata) {
        self.fontSize = fontSize
    }
    
    var body: some View {
        Text("•")
            .font(fontSize)
            .foregroundStyle(DSColor.secondary)
    }
}

// MARK: - Helper Extension (unchanged)
extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}



