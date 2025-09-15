//
//  ArtistDebugView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 15.09.25.
//


//
//  ArtistDebugView.swift - Debug Tool for Artist Images
//  NavidromeClient
//
//  Temporäres Debug Tool um Artist Image Loading zu analysieren
//

import SwiftUI

#if DEBUG
struct ArtistDebugView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    var body: some View {
        NavigationView {
            List {
                Section("Artist Image Debug") {
                    ForEach(navidromeVM.artists.prefix(10), id: \.id) { artist in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name: \(artist.name)")
                                .font(.headline)
                            
                            Text("ID: \(artist.id)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("coverArt:")
                                Text(artist.coverArt ?? "nil")
                                    .foregroundColor(artist.coverArt != nil ? .green : .red)
                            }
                            .font(.caption)
                            
                            HStack {
                                Text("artistImageUrl:")
                                Text(artist.artistImageUrl ?? "nil")
                                    .foregroundColor(artist.artistImageUrl != nil ? .blue : .red)
                            }
                            .font(.caption)
                            
                            HStack {
                                Text("Has cached image:")
                                let hasImage = coverArtService.artistImage(for: artist, size: 120) != nil
                                Text(hasImage ? "Yes" : "No")
                                    .foregroundColor(hasImage ? .green : .orange)
                                
                                Button("Load") {
                                    Task {
                                        print("🔄 Manual load for \(artist.name)")
                                        let result = await coverArtService.loadArtistImage(artist, size: 120)
                                        print("   Result: \(result != nil ? "success" : "failed")")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                            .font(.caption)
                            
                            Divider()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Artist Debug")
            .onAppear {
                // Print first few artists for analysis
                print("🎨 DEBUG: First 5 artists analysis:")
                for artist in navidromeVM.artists.prefix(5) {
                    print("Artist: \(artist.name)")
                    print("  - coverArt: \(artist.coverArt ?? "nil")")
                    print("  - artistImageUrl: \(artist.artistImageUrl ?? "nil")")
                    print("  - albumCount: \(artist.albumCount ?? 0)")
                }
            }
        }
    }
}
#endif

// Usage: Add this to your app temporarily
// #if DEBUG
// .sheet(isPresented: $showDebug) {
//     ArtistDebugView()
//         .environmentObject(navidromeVM)
//         .environmentObject(coverArtService)
// }
// #endif