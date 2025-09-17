//
//  MiniPlayerView.swift - Enhanced with Design System
//  NavidromeClient
//
//  ✅ ENHANCED: Vollständige Anwendung des Design Systems
//

import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var audioSessionManager: AudioSessionManager
    @State private var isDragging = false
    @State private var showFullScreen = false
    
    var body: some View {
        if let song = playerVM.currentSong {
            VStack(spacing: 0) {
                // MARK: Progress Bar (Enhanced with DS)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(DSColor.surfaceSecondary)
                            .frame(height: 4)
                            .cornerRadius(DSCorners.tight)
                        
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [DSColor.accent, DSColor.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geometry.size.width * progressPercentage, height: 4)
                            .cornerRadius(DSCorners.tight)
                            .animation(isDragging ? nil : Animations.easeQuick, value: progressPercentage)
                        
                        // Drag Zone
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        isDragging = true
                                        let progress = max(0, min(value.location.x / geometry.size.width, 1))
                                        let newTime = progress * playerVM.duration
                                        playerVM.seek(to: newTime)
                                    }
                                    .onEnded { _ in
                                        isDragging = false
                                    }
                            )
                    }
                }
                .frame(height: 4)
                
                // MARK: Player HStack (Enhanced with DS)
                HStack(spacing: DSLayout.contentGap) {
                    // Cover + Song Info
                    HStack(spacing: DSLayout.contentGap) {
                        // Cover Art with Audio Route Indicator
                        ZStack {
                            Group {
                                if let cover = playerVM.coverArt {
                                    Image(uiImage: cover)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    Rectangle()
                                        .fill(LinearGradient(
                                            colors: [DSColor.surface, DSColor.surfaceSecondary],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .overlay(
                                            Image(systemName: "music.note")
                                                .font(.system(size: DSLayout.icon))
                                                .foregroundStyle(DSColor.tertiary)
                                        )
                                }
                            }
                            .frame(width: DSLayout.miniCover, height: DSLayout.miniCover)
                            .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
                            
                            // Audio Route Indicator
                            if audioSessionManager.isHeadphonesConnected {
                                VStack {
                                    HStack {
                                        Spacer()
                                        Image(systemName: audioSessionManager.audioRoute.contains("Bluetooth") ? "bluetooth" : "headphones")
                                            .font(DSText.body)
                                            .foregroundStyle(DSColor.onDark)
                                            .padding(DSLayout.tightPadding)
                                            .background(Circle().fill(DSColor.accent))
                                    }
                                    Spacer()
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                            Text(song.title)
                                .font(DSText.prominent)
                                .lineLimit(1)
                                .foregroundStyle(DSColor.primary)
                            
                            HStack(spacing: DSLayout.tightGap) {
                                if let artist = song.artist {
                                    Text(artist)
                                        .font(DSText.sectionTitle)
                                        .foregroundStyle(DSColor.secondary)
                                        .lineLimit(1)
                                }
                                
                                // Loading indicator
                                if playerVM.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .frame(width: 12, height: 12) // Approx. DS applied
                                }
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showFullScreen = true
                    }
                    
                    Spacer()
                    
                    // MARK: Controls (Enhanced with DS)
                    HStack(spacing: DSLayout.sectionGap) {
                        Button {
                            Task { await playerVM.playPrevious() }
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: DSLayout.icon))
                                .foregroundStyle(DSColor.primary)
                        }
                        .disabled(playerVM.isLoading)
                        
                        Button {
                            playerVM.togglePlayPause()
                        } label: {
                            ZStack {
                                if playerVM.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: DSColor.onDark))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: DSLayout.largeIcon))
                                        .foregroundStyle(DSColor.onDark)
                                }
                            }
                            .frame(width: 40, height: 40) // Approx. DS applied - könnte Sizes.buttonHeight - 4 sein
                            .background(
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [DSColor.accent, DSColor.secondary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                            )
                        }
                        .disabled(playerVM.isLoading)
                        
                        Button {
                            Task { await playerVM.playNext() }
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: DSLayout.icon))
                                .foregroundStyle(DSColor.primary)
                        }
                        .disabled(playerVM.isLoading)
                    }
                }
                .listItemPadding()
                .background(DSColor.background)
                
                // MARK: Audio Session Status Bar (Debug - Enhanced with DS)
                if ProcessInfo.processInfo.environment["DEBUG_AUDIO"] == "1" {
                    AudioStatusBar()
                        .environmentObject(audioSessionManager)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        playerVM.stop()
                    }
            )
            .gesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onEnded { value in
                        if value.translation.height > 50 { // Swipe nach unten
                            playerVM.stop()
                        }
                    }
            )
            .clipShape(RoundedRectangle(cornerRadius: 0))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(Animations.spring, value: playerVM.currentSong?.id)
            .fullScreenCover(isPresented: $showFullScreen) {
                FullScreenPlayerView()
                    .environmentObject(playerVM)
                    .environmentObject(navidromeVM)
                    .environmentObject(audioSessionManager)
            }
        }
    }
    
    private var progressPercentage: Double {
        guard playerVM.duration > 0 else { return 0 }
        return playerVM.currentTime / playerVM.duration
    }
}

// MARK: - Audio Status Bar (Enhanced with DS)
struct AudioStatusBar: View {
    @EnvironmentObject var audioSessionManager: AudioSessionManager
    
    var body: some View {
        HStack(spacing: DSLayout.elementGap) {
            // Audio Session Status
            Circle()
                .fill(audioSessionManager.isAudioSessionActive ? DSColor.success : DSColor.error)
                .frame(width: 6, height: 6) // Approx. DS applied
            
            Text("Audio: \(audioSessionManager.audioRoute)")
                .font(DSText.body)
                .foregroundStyle(DSColor.secondary)
            
            if audioSessionManager.isHeadphonesConnected {
                Image(systemName: "headphones")
                    .font(DSText.body)
                    .foregroundStyle(DSColor.accent)
            }
            
            Spacer()
        }
        .listItemPadding()
        .background(DSColor.background)
    }
}
