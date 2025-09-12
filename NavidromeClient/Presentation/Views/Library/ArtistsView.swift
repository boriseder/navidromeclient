import SwiftUI

import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    
    @State private var searchText = ""
    @State private var hasLoadedOnce = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                DynamicMusicBackground()
                
                if navidromeVM.isLoading {
                    loadingView()
                } else {
                    mainContent
                }
            }
            .navigationTitle("Artists")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchText, placement: .automatic, prompt: "Search artists...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task {
                            await navidromeVM.loadArtists()
                            hasLoadedOnce = true
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(navidromeVM.isLoading)
                }
            }
            .task {
                if !hasLoadedOnce {
                    await navidromeVM.loadArtists()
                    hasLoadedOnce = true
                }
            }
            .refreshable {
                await navidromeVM.loadArtists()
                hasLoadedOnce = true
            }
            .navigationDestination(for: Artist.self) { artist in
                ArtistDetailView(context: .artist(artist))
                    .environmentObject(navidromeVM)
                    .environmentObject(playerVM)
            }
            .accountToolbar()
        }
    }

    private var filteredArtists: [Artist] {
        if searchText.isEmpty {
            return navidromeVM.artists.sorted(by: { $0.name < $1.name })
        } else {
            return navidromeVM.artists
                .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                .sorted(by: { $0.name < $1.name })
        }
    }

    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(filteredArtists.enumerated()), id: \.element.id) { index, artist in
                    NavigationLink(value: artist) {
                        ArtistCard(artist: artist, index: index)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 90)
        }
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
                Circle()
                    .fill(.black.opacity(0.1))
                    .frame(width: 70, height: 70)
                    .blur(radius: 1)
                
                // Main avatar
                Group {
                    if let image = artistImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 70, height: 70)
                            .clipShape(Circle())
                    } else if isLoadingImage {
                        Circle()
                            .fill(.regularMaterial)
                            .frame(width: 70, height: 70)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.primary)
                            )
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.red, Color.blue.opacity(0.7)],
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
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Image(systemName: "record.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    
                    if let count = artist.albumCount {
                        Text("\(count) Album\(count != 1 ? "s" : "")")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)

                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
        )
    }
    
    // MARK: - Helper Methods
    private func loadArtistImage() async {
        guard let coverId = artist.coverArt, !isLoadingImage else { return }
        isLoadingImage = true
        
        // This already goes through cache via NavidromeVM -> Service -> PersistentImageCache
        artistImage = await navidromeVM.loadCoverArt(for: coverId)
        
        isLoadingImage = false
    }
}
