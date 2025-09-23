//
//  ArtistDetailHeaderView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 23.09.25.
//
import SwiftUI

// MARK: - Extracted Header View

struct AlbumCollectionHeaderView: View {
    let context: AlbumCollectionContext
    let artistImage: UIImage?
    let contextTitle: String
    let albumCountText: String
    let contextIcon: String

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // MARK: - Background with artist image blur
                if case .artist = context, let artistImage {
                    Image(uiImage: artistImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 300)
                        .clipped()
                        .blur(radius: 30)
                        .overlay(
                            LinearGradient(
                                colors: [.black.opacity(0.5), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .ignoresSafeArea(edges: .top)
                } else {
                    // Placeholder for genre or missing image
                    /*
                    Color.gray.opacity(0.3)
                        .frame(height: 300)
                        .ignoresSafeArea(edges: .top)
                     */
                }
                
                // MARK: - Avatar / Placeholder + Title + Album count
                VStack(spacing: 16) {
                    if case .artist = context, let artistImage {
                        Image(uiImage: artistImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 200, height: 200)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 4
                                    )
                            )
                            .shadow(radius: 8)
                        
                            Text(contextTitle)
                                .font(DSText.prominent)
                                .foregroundColor(DSColor.onDark)
                                .multilineTextAlignment(.center)
                            
                            Text(albumCountText)
                            .font(DSText.emphasized)
                                .foregroundColor(DSColor.onDark.opacity(0.8))

                    } else {
                        /*
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 140, height: 140)
                            .overlay(
                                Image(systemName: contextIcon)
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                            )
                         */
                        VStack{
                            Text(contextTitle)
                                .font(DSText.sectionTitle)
                                .foregroundColor(DSColor.onLight)
                                .multilineTextAlignment(.center)
                            
                            Text(albumCountText)
                                .font(DSText.emphasized)
                                .foregroundColor(DSColor.onLight.opacity(0.8))
                        }
                        .padding(.horizontal, DSLayout.screenPadding)
                        .padding(.top, DSLayout.screenPadding)

                    }
                    
                }
            }
            .padding(.bottom, 24)
        }
        .screenPadding()
        
    }
}
