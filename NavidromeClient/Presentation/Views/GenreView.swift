import SwiftUI

struct GenreView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel

    @State private var searchText = ""
    @State private var dominantColors: [Color] = [.blue, .purple]

    private var filteredGenres: [Genre] {
        if searchText.isEmpty {
            return navidromeVM.genres.sorted(by: { $0.value < $1.value })
        } else {
            return navidromeVM.genres
                .filter { $0.value.localizedCaseInsensitiveContains(searchText) }
                .sorted(by: { $0.value < $1.value })
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
                .environmentObject(navidromeVM)

                if navidromeVM.isLoading {
                    loadingView
                } else {
                    mainContent
                }
            }
            .navigationTitle("Genres")
            .navigationBarTitleDisplayMode(.large)
            /*
             .searchable(text: $searchText, prompt: "Search genres...")
            */
            .task {
                await navidromeVM.loadGenres()
            }
            .navigationDestination(for: Genre.self) { genre in
                ArtistDetailView(context: .genre(genre))
                    .environmentObject(navidromeVM)
                    .environmentObject(playerVM)
            }
            .accountToolbar()  // hier wird das Icon hinzugefügt
        }
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
            
            Text("Loading Genres...")
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

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("No genres found")
                .font(.title3.weight(.semibold))
            Text("Try adjusting your search or check your music library.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Main Content
    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Stats Header
                if !filteredGenres.isEmpty {
                    statsHeader
                        .padding(.top, 10)
                }

                // Genres Grid
                ForEach(filteredGenres, id: \.id) { genre in
                    NavigationLink(value: genre) {
                        GenreCard(genre: genre)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100) // Platz für MiniPlayer
        }
    }

    // MARK: - Stats Header
    private var statsHeader: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("\(filteredGenres.count)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                Text("Genres")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            VStack(spacing: 4) {
                let totalAlbums = filteredGenres.reduce(0) { $0 + $1.albumCount }
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
}

// MARK: - Genre Card
struct GenreCard: View {
    let genre: Genre

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(.blue.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(genre.value)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                HStack(spacing: 5) {
                     Image(systemName: "record.circle.fill")
                         .font(.caption)
                         .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                     
                     let count = genre.albumCount
                    Text("\(count) Album\(count != 1 ? "s" : "")")
                     .font(.caption.weight(.medium))
                     .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                }
                 
            }
            
            
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}
