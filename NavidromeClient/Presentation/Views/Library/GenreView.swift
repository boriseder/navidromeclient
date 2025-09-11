import SwiftUI

struct GenreView: View {
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
            .navigationTitle("Genres")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchText, placement: .automatic, prompt: "Search genres...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task {
                            await navidromeVM.loadGenres()
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
                    await navidromeVM.loadGenres()
                    hasLoadedOnce = true
                }
            }
            .refreshable {
                await navidromeVM.loadGenres()
                hasLoadedOnce = true
            }
            .navigationDestination(for: Genre.self) { genre in
                ArtistDetailView(context: .genre(genre))
                    .environmentObject(navidromeVM)
                    .environmentObject(playerVM)
            }
            .accountToolbar()
        }
    }
    
    private var filteredGenres: [Genre] {
        if searchText.isEmpty {
            return navidromeVM.genres.sorted(by: { $0.value < $1.value })
        } else {
            return navidromeVM.genres
                .filter { $0.value.localizedCaseInsensitiveContains(searchText) }
                .sorted(by: { $0.value < $1.value })
        }
    }

    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredGenres, id: \.id) { genre in
                    NavigationLink(value: genre) {
                        GenreCard(genre: genre)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 90)
        }
    }
}

// MARK: - Genre Card
struct GenreCard: View {
    let genre: Genre

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(.black.opacity(0.1))
                .frame(width: 44, height: 44)
                .blur(radius: 1)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundStyle(.white)
                )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(genre.value)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Image(systemName: "record.circle.fill")
                         .font(.caption)
                         .foregroundColor(.secondary)

                     
                    let count = genre.albumCount
                    Text("\(count) Album\(count != 1 ? "s" : "")")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)

                }
                 
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
