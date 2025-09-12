//
//  HomeScreenView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 04.09.25.
//

import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @StateObject private var homeVM = HomeScreenViewModel()
    @State private var showRefreshAnimation = false
    
    var body: some View {
        NavigationView {
            ZStack {
               DynamicMusicBackground()

                ScrollView {
                    LazyVStack(spacing: 32) {
                        // Welcome Header
                        HomeWelcomeHeader()
                            .padding(.horizontal, 20)
                        
                        // Recent Albums
                        if !homeVM.recentAlbums.isEmpty {
                            AlbumSection(
                                title: "Recently played",
                                albums: homeVM.recentAlbums,
                                icon: "clock.fill",
                                accentColor: .orange
                            )
                        }
                        
                        // Newest Albums
                        if !homeVM.newestAlbums.isEmpty {
                            AlbumSection(
                                title: "Newly added",
                                albums: homeVM.newestAlbums,
                                icon: "sparkles",
                                accentColor: .green
                            )
                        }
                        
                        // Most Played Albums
                        if !homeVM.frequentAlbums.isEmpty {
                            AlbumSection(
                                title: "Often played",
                                albums: homeVM.frequentAlbums,
                                icon: "chart.bar.fill",
                                accentColor: .purple
                            )
                        }
                        
                        // Random Albums
                        if !homeVM.randomAlbums.isEmpty {
                            AlbumSection(
                                title: "Explore",
                                albums: homeVM.randomAlbums,
                                icon: "dice.fill",
                                accentColor: .blue,
                                showRefreshButton: true,
                                refreshAction: {
                                    await refreshRandomAlbums()
                                }
                            )
                        }
                        
                        // Loading state
                        if homeVM.isLoading {
                            loadingView()
                        }
                        
                        // Error state
                        if let errorMessage = homeVM.errorMessage {
                            ErrorSection(message: errorMessage)
                        }
                        
                        // Bottom padding for mini player
                        Color.clear.frame(height: 90)
                    }
                    .padding(.top, 10)
                }
                .refreshable {
                    await homeVM.loadHomeScreenData()
                }
            }
            .navigationTitle("Music")
            .navigationBarTitleDisplayMode(.large)
            .task {
                homeVM.configure(with: navidromeVM)
                await homeVM.loadHomeScreenData()
            }
            .accountToolbar()
        }
    }
    
    private func refreshRandomAlbums() async {
        showRefreshAnimation = true
        await homeVM.refreshRandomAlbums()
        showRefreshAnimation = false
    }
}

// MARK: - Welcome Header
struct HomeWelcomeHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greetingText())
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.black.opacity(0.8))
                    
                    Text("Enjoy your music")
                        .font(.subheadline)
                        .foregroundColor(.black.opacity(0.6))
                }
                
                Spacer()
                
                // Current time
                Text(currentTimeString())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.5))
            }
        }
    }
    
    private func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }
    
    private func currentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

// MARK: - Album Section
struct AlbumSection: View {
    let title: String
    let albums: [Album]
    let icon: String
    let accentColor: Color
    var showRefreshButton: Bool = false
    var refreshAction: (() async -> Void)? = nil
    
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.9))
                
                Spacer()
                
                if showRefreshButton, let refreshAction = refreshAction {
                    Button {
                        Task {
                            isRefreshing = true
                            await refreshAction()
                            isRefreshing = false
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline)
                            .foregroundColor(accentColor)
                            .rotationEffect(isRefreshing ? .degrees(360) : .degrees(0))
                            .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                    }
                    .disabled(isRefreshing)
                }
            }
            .padding(.horizontal, 20)
            
            // Horizontal Album Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(albums) { album in
                        NavigationLink(destination: AlbumDetailView(album: album)) {
                            AlbumCard(album: album, accentColor: accentColor)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Album Card


// MARK: - Error Section
struct ErrorSection: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.black.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
}
