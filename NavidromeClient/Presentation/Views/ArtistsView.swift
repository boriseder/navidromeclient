import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    
    @State private var searchText = ""
    @State private var dominantColors: [Color] = [.yellow, .cyan]
    @State private var showingSettings = false
    
    private var filteredArtists: [Artist] {
        if searchText.isEmpty {
            return navidromeVM.artists.sorted(by: { $0.name < $1.name })
        } else {
            return navidromeVM.artists
                .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                .sorted(by: { $0.name < $1.name })
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MusicBackgroundView(
                    artist: nil,
                    genre: nil,
                    album: nil
                )
                
                if navidromeVM.isLoading {
                    loadingView
                } else {
                    mainContent
                }
            }
            .navigationTitle("Artists")
            .navigationBarTitleDisplayMode(.large)
            /*
             .searchable(
                text: $searchText, placement: .automatic, prompt: "Search artists...")
            */
            .task {
                await navidromeVM.loadArtists()
            }
            .navigationDestination(for: Artist.self) { artist in
                ArtistDetailView(context: .artist(artist))
                    .environmentObject(navidromeVM)
                    .environmentObject(playerVM)
            }
            .accountToolbar()  // hier wird das Icon hinzugefügt
        }
   }

    
    
    
    
    
    // MARK: - Not Configured View
        private var notConfiguredView: some View {
            VStack(spacing: 30) {
                Image(systemName: "gear.badge.questionmark")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 12) {
                    Text("Setup Required")
                        .font(.title2.weight(.semibold))
                    
                    Text("Please configure your Navidrome server connection in Settings")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Button("Open Settings") {
                    showingSettings = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        
        // MARK: - Loading View
        private var loadingView: some View {
            VStack(spacing: 24) {
                // Animated loading circles
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color(.systemIndigo))
                            .frame(width: 12, height: 12)
                            .scaleEffect(navidromeVM.isLoading ? 1.0 : 0.5)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                                value: navidromeVM.isLoading
                            )
                    }
                }
                
                Text("Loading Artists...")
                    .font(.headline.weight(.medium))
                    .foregroundStyle(.primary)
                
                Text("Discovering your music library")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(radius: 20, y: 10)
        }
        
        // MARK: - Empty State View
        private var emptyStateView: some View {
            VStack(spacing: 24) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 12) {
                    Text("No Artists Found")
                        .font(.title2.weight(.semibold))
                    
                    Text("Your music library appears to be empty, or there might be a connection issue.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Button("Retry") {
                    Task {
                        await navidromeVM.loadArtists()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        
        // MARK: - Main Content
        private var mainContent: some View {
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Stats Header
                    if !filteredArtists.isEmpty {
                        statsHeader
                            .padding(.top, 10)
                    }
                    
                    // Artists List
                    ForEach(Array(filteredArtists.enumerated()), id: \.element.id) { index, artist in
                        NavigationLink(value: artist) {
                            ArtistCard(artist: artist, index: index)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        }
        
        // MARK: - Stats Header
        private var statsHeader: some View {
            HStack(spacing: 16) {
                // Total Artists
                VStack(spacing: 4) {
                    Text("\(filteredArtists.count)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("Artists")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                // Total Albums
                VStack(spacing: 4) {
                    let totalAlbums = filteredArtists.compactMap { $0.albumCount }.reduce(0, +)
                    Text("\(totalAlbums)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("Albums")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 10)
        }
        
        // MARK: - Helper Methods
        private func loadArtistsIfNeeded() async {
            // Nur laden, wenn konfiguriert und noch keine Artists geladen
            if appConfig.isConfigured && navidromeVM.artists.isEmpty {
                await navidromeVM.loadArtists()
            }
        }
    }

// MARK: - Enhanced Artist Card
struct ArtistCard: View {
    let artist: Artist
    let index: Int
    
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @State private var artistImage: UIImage?
    @State private var isLoadingImage = false
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Artist Avatar with glow
            ZStack {
                // Subtle glow background
                Circle()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: 70, height: 70)
                    .blur(radius: 3)
                
                // Main avatar
                Group {
                    if let image = artistImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                         
                    } else if isLoadingImage {
                        Circle()
                            .fill(.regularMaterial)
                            .frame(width: 60, height: 60)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(Color.green)
                            )
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.red, Color.green.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "music.mic")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white.opacity(0.9))
                            )
                    }
                }
            }
            .task {
                await loadArtistImage()
            }

            // Artist Info
            VStack(alignment: .leading, spacing: 6) {
                Text(artist.name)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Image(systemName: "record.circle.fill")
                        .font(.caption)
                        .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                    
                    if let count = artist.albumCount {
                        Text("\(count) Album\(count != 1 ? "s" : "")")
                            .font(.caption.weight(.medium))
                            .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                    }
                }
            }

            Spacer()

            // Chevron with accent color
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }
    
    // MARK: - Helper Methods
    private func loadArtistImage() async {
        guard let coverId = artist.coverArt, !isLoadingImage else { return }
        isLoadingImage = true
        artistImage = await navidromeVM.loadCoverArt(for: coverId)
        isLoadingImage = false
    }
}
