//
//  AlbumCollectionHeaderView.swift
//  NavidromeClient
//
//  Modern iOS-like header with large hero image and floating action buttons
//

import SwiftUI

struct AlbumCollectionHeaderView: View {
    let context: AlbumCollectionContext
    let artistImage: UIImage?
    let contextTitle: String
    let albumCountText: String
    let contextIcon: String
    let onPlayAll: () -> Void
    let onShuffle: () -> Void
    
    var body: some View {
        ZStack {

            // MARK: - Background Layer
            if case .byArtist = context, let artistImage {
                backgroundImageLayer(artistImage)
            }
            
            // MARK: - Content Layer
            contentLayer
        }
        .frame(height: headerHeight)
        .ignoresSafeArea(edges: .top)
    }
    
    // MARK: - Background Image Layer
    
    @ViewBuilder
    private func backgroundImageLayer(_ artistImage: UIImage) -> some View {
        Image(uiImage: artistImage)
            .resizable()
            .scaledToFill()
            .frame(
                width: UIScreen.main.bounds.width,
                height: headerHeight + 150
            )
            .blur(radius: 30)
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .black.opacity(0.4),
                                .black.opacity(0.1),
                                .clear,
                                .black.opacity(0.8)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .offset(y: -75)
            .ignoresSafeArea(edges: .all)
    }
    
    // MARK: - Content Layer
    
    @ViewBuilder
    private var contentLayer: some View {
            
            
            VStack(spacing: DSLayout.screenGap) {
                if case .byArtist = context, let artistImage {
                    artistHeroContent(artistImage)
                } else if case .byGenre = context {
                    genreContent
                }
            }
            .frame(maxWidth: .infinity)
            
            // Reduced bottom spacing
            Color.clear.frame(height: DSLayout.contentGap)
    }
    
    // MARK: - Artist Hero Content
    
    @ViewBuilder
    private func artistHeroContent(_ artistImage: UIImage) -> some View {
        VStack(spacing: DSLayout.screenGap) {
            
            // Large hero image with modern styling
            Image(uiImage: artistImage)
                .resizable()
                .scaledToFill()
                .frame(width: 240, height: 240)
                .clipShape(
                    RoundedRectangle(cornerRadius: 32)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(
                            .white.opacity(0.15),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: .black.opacity(0.5),
                    radius: 20,
                    x: 0,
                    y: 10
                )
                .shadow(
                    color: .black.opacity(0.2),
                    radius: 40,
                    x: 0,
                    y: 20
                )
            
            // Artist info with iOS-style typography
            VStack(spacing: DSLayout.tightGap) {
                Text(contextTitle)
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                Text(albumCountText)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                    .lineLimit(1)
            }
            .padding(.horizontal, DSLayout.screenPadding)
            // Modern floating action buttons
            actionButtonsFloating
                .padding(.bottom, DSLayout.screenGap)

        }
    }
    
    // MARK: - Genre Content
    
    @ViewBuilder
    private var genreContent: some View {
        VStack(spacing: DSLayout.elementGap) {
            
            // Genre icon with modern styling
            Image(systemName: contextIcon)
                .font(.system(size: 60, weight: .medium))
                .foregroundStyle(DSColor.accent)
                .frame(width: 120, height: 120)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(DSColor.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(DSColor.accent.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(
                    color: DSColor.accent.opacity(0.15),
                    radius: 12,
                    x: 0,
                    y: 6
                )
            
            // Genre info
            VStack(spacing: DSLayout.tightGap) {
                Text(contextTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(DSColor.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                Text(albumCountText)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(DSColor.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, DSLayout.screenPadding)
        }
        .padding(.top, DSLayout.screenGap)
    }
    
    // MARK: - Floating Action Buttons
    
    @ViewBuilder
    private var actionButtonsFloating: some View {
        HStack(spacing: DSLayout.elementGap) {
            
            // Play All Button - Primary action
            Button(action: onPlayAll) {
                HStack(spacing: DSLayout.contentGap) {
                    Image(systemName: "play.fill")
                        .font(DSText.emphasized)
                    Text("Play All")
                        .font(DSText.emphasized)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DSLayout.contentPadding)
                .padding(.vertical, DSLayout.elementPadding)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.8, blue: 0.2),
                                    Color(red: 0.15, green: 0.7, blue: 0.15)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                        .shadow(color: .green.opacity(0.3), radius: 12, x: 0, y: 6)
                )
            }
            
            // Shuffle Button - Secondary action
            Button(action: onShuffle) {
                HStack(spacing: DSLayout.contentGap) {
                    Image(systemName: "shuffle")
                        .font(DSText.emphasized)
                    Text("Shuffle")
                        .font(DSText.emphasized)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DSLayout.contentPadding)
                .padding(.vertical, DSLayout.elementPadding)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.25),
                                    .white.opacity(0.15)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                )
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var headerHeight: CGFloat {
        switch context {
        case .byArtist: return 400
        case .byGenre: return 250
        }
    }
}

// MARK: - Convenience Initializers

extension AlbumCollectionHeaderView {
    init(
        context: AlbumCollectionContext,
        artistImage: UIImage?,
        contextTitle: String,
        albumCountText: String,
        contextIcon: String
    ) {
        self.init(
            context: context,
            artistImage: artistImage,
            contextTitle: contextTitle,
            albumCountText: albumCountText,
            contextIcon: contextIcon,
            onPlayAll: {},
            onShuffle: {}
        )
    }
}
