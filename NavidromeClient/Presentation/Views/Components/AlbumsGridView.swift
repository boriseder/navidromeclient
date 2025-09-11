import SwiftUI

// MARK: - Reusable Album Grid View
struct AlbumGridView: View {
    let albums: [Album]
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    
    var body: some View {
        ScrollView {
            albumsGrid
                .padding(.horizontal, 16)
                .padding(.bottom, 100) // Platz für Mini-Player
        }
    }
    
    // Das bestehende Grid aus ArtistDetailView - extrahiert für Wiederverwendung
    private var albumsGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
        
        return LazyVGrid(columns: columns, spacing: 20) {
            ForEach(albums, id: \.id) { album in
                NavigationLink {
                    AlbumDetailView(album: album)
                        .environmentObject(navidromeVM)
                        .environmentObject(playerVM)
                } label: {
                    AlbumGridCard(
                        album: album,
                        cover: nil // Cover wird async geladen
                    )
                    .task {
                        // Async Cover Loading - wird in AlbumGridCard gehandhabt
                    }
                }
            }
        }
    }
}

// MARK: - Enhanced Album Grid Card (mit Download Status)
struct AlbumGridCard: View {
    let album: Album
    let cover: UIImage?
    
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var loadedCover: UIImage?
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 12) {
            albumCover
            albumInfo
        }
        .padding(16)
        .frame(height: 240)
        .background(cardBackground)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(duration: 0.2, bounce: 0.3), value: isPressed)
        .task {
            // Load cover if not provided
            if cover == nil && loadedCover == nil {
                loadedCover = await navidromeVM.loadCoverArt(for: album.id, size: 200)
            }
        }
    }
    
    private var albumCover: some View {
        ZStack {
            Group {
                if let displayCover = cover ?? loadedCover {
                    Image(uiImage: displayCover)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholderCover
                }
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(
                color: Color.red.opacity(0.2),
                radius: isPressed ? 8 : 12,
                x: 0, y: isPressed ? 4 : 8
            )
            
            // Download Status Badge
            VStack {
                HStack {
                    Spacer()
                    downloadStatusBadge
                }
                Spacer()
            }
            .padding(8)
        }
    }
    
    private var placeholderCover: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.1))
            .overlay(
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.2), lineWidth: 2)
                        .frame(width: 60, height: 60)
                    Image(systemName: "opticaldisc")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.green.opacity(0.7))
                }
            )
    }
    
    @ViewBuilder
    private var downloadStatusBadge: some View {
        if downloadManager.isAlbumDownloading(album.id) {
            Circle()
                .fill(.blue)
                .frame(width: 24, height: 24)
                .overlay(
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                )
        } else if downloadManager.isAlbumDownloaded(album.id) {
            Circle()
                .fill(.green)
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundStyle(.white)
                )
        }
    }
    
    private var albumInfo: some View {
        VStack(spacing: 4) {
            Text(album.name)
                .font(.headline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(white: 0.2))
                .frame(height: 32)
            
            albumMetadata
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
    }
    
    private var albumMetadata: some View {
        HStack(spacing: 6) {
            if let year = album.year {
                metadataItem(icon: "calendar", text: "\(year)")
            }
            
            if album.year != nil && album.songCount ?? 0 > 0 {
                metadataSeparator()
            }
            
            if album.songCount ?? 0 > 0 {
                metadataItem(icon: "music.note", text: "\(album.songCount ?? 0)")
            }
        }
        .frame(height: 16)
    }
    
    private func metadataItem(icon: String, text: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.2))
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.2))
        }
    }
    
    private func metadataSeparator() -> some View {
        Text("•")
            .font(.system(size: 12))
            .foregroundColor(Color(white: 0.2))
    }
    
    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
        }
    }
}
