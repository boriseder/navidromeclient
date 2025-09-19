//
//  FullScreenPlayerView.swift - FIXED: Layout & High-Res
//  NavidromeClient
//
//   FIXED: Alles bleibt im Screen, echte High-Res, Timeline-Indikator
//

import SwiftUI
import AVKit

struct FullScreenPlayerView: View {

    @EnvironmentObject var deps: AppDependencies
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var showingQueue = false
    @State private var highResCoverArt: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {

               //SpotifyBackground(image: highResCoverArt ?? deps.playerVM.coverArt)
                
                VStack(spacing: 5) {
                    // Top Bar
                    
                    TopBar(dismiss: dismiss, showingQueue: $showingQueue)
                        .padding(.horizontal, 20)
                    Spacer(minLength: 30)
                    SpotifyAlbumArt(cover: highResCoverArt ?? deps.playerVM.coverArt, screenWidth: geometry.size.width)
                        .scaleEffect(isDragging ? 0.95 : 1.0)
                        .animation(.spring(response: 0.3), value: isDragging)
                    
                    Spacer(minLength: 20)

                    if let song = deps.playerVM.currentSong {
                        SpotifySongInfoView(song: song, screenWidth: geometry.size.width)
                    }
                                        
                    Spacer(minLength: 16)
                    
                    // FIXED: Progress mit Timeline-Indikator
                    ProgressSection(screenWidth: geometry.size.width)
                    
                    Spacer(minLength: 24)
                    
                    MainControls()
                    
                    Spacer()
                    BottomControls(screenWidth: geometry.size.width)
                      //  .padding(.bottom, max(20, geometry.safeAreaInsets.bottom))

                }
                .frame(maxWidth: geometry.size.width*0.95, maxHeight: geometry.size.height*0.95)
                // FOR DEBUG only
                //.background(.red)
                .padding(.horizontal, 10)
                .padding(.top, 70)
                .padding(.bottom, 20)
                .background {
                    SpotifyBackground(image: highResCoverArt ?? deps.playerVM.coverArt)
                }

            }
            .ignoresSafeArea(.container, edges: [.top, .bottom])
            .offset(y: dragOffset)
            .gesture(dismissGesture)
        }
        .animation(.interactiveSpring(), value: dragOffset)
        .task(id: deps.playerVM.currentSong?.id) {
            await loadTrueHighResCoverArt()
        }
    }
    
    private var dismissGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height > 0 {
                    dragOffset = value.translation.height
                    isDragging = true
                }
            }
            .onEnded { value in
                isDragging = false
                if value.translation.height > 200 {
                    dismiss()
                } else {
                    withAnimation(.spring()) {
                        dragOffset = 0
                    }
                }
            }
    }
    
    // FIXED: Force echte High-Res mit size parameter
    private func loadTrueHighResCoverArt() async {
        guard let song = deps.playerVM.currentSong,
              let albumId = song.albumId else { return }
        
        if let cachedAlbum = AlbumMetadataCache.shared.getAlbum(id: albumId) {
            // ✅ FIXED: Load 800px + Check if bereits geladen
            if let existingHighRes = deps.coverArtManager.getAlbumImage(for: albumId, size: 1200) {
                print("🎯 High-res cache hit: \(existingHighRes.size.width)x\(existingHighRes.size.height)")
                highResCoverArt = existingHighRes
                return
            }
            
            // Load fresh 800px
            let highRes = await deps.coverArtManager.loadAlbumImage(
                album: cachedAlbum,
                size: 800,
                staggerIndex: 0
            )
            
            if let image = highRes {
                print("🖼️ High-res loaded: \(image.size.width)x\(image.size.height)")
                await MainActor.run {
                    self.highResCoverArt = image
                }
            }
        }
    }
}

// MARK: - FIXED: Noch intensiverer Background Blur
struct SpotifyBackground: View {
    let image: UIImage?
    
    var body: some View {
        ZStack {
            //Color.black.ignoresSafeArea()
            Color.black
            
            if let cover = image {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    //.ignoresSafeArea()
                    .blur(radius: 20)     // FIXED: Noch stärker
                    .opacity(0.9)          // FIXED: Noch sichtbarer
                    .scaleEffect(1.4)      // FIXED: Noch größer
                    .brightness(-0.4)      // FIXED: Noch dunkler
            }
        }
    }
}

// MARK: - Top Bar (unverändert)
struct TopBar: View {
    let dismiss: DismissAction
    @Binding var showingQueue: Bool
    
    var body: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            Button {
                showingQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - FIXED: Album Art mit fester Breite
struct SpotifyAlbumArt: View {
    let cover: UIImage?
    let screenWidth: CGFloat
    
    var body: some View {
        Group {
            if let cover = cover {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray)
                    )
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .frame(width: min(280, screenWidth - 80), height: min(280, screenWidth - 80))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
    }
}

// MARK: - FIXED: Song Info ohne Overflow
struct SpotifySongInfoView: View {
    let song: Song
    let screenWidth: CGFloat
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let artist = song.artist {
                    Text(artist)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Button {
                // TODO: Implement favorite
            } label: {
                Image(systemName: "heart")
                    .font(.system(size: 26))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - FIXED: Progress Section mit Timeline-Indikator
struct ProgressSection: View {
    @EnvironmentObject var deps: AppDependencies
    let screenWidth: CGFloat
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.3))
                        .frame(height: 4)
                    
                    // Progress track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white)
                        .frame(width: progressWidth(geometry.size.width), height: 4)
                    
                    Circle()
                        .fill(.white)
                        .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                        .offset(x: progressWidth(geometry.size.width) - (isDragging ? 8 : 6))
                        .animation(.easeInOut(duration: 0.1), value: isDragging)
                }
                .gesture(progressGesture(geometry.size.width))
            }
            .frame(height: 20)
            
            // Time Labels
            HStack {
                Text(formatTime(isDragging ? dragValue * deps.playerVM.duration : deps.playerVM.currentTime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
                
                Text(formatTime(deps.playerVM.duration))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: screenWidth - 40)
        .padding(.horizontal, 20)
    }
    
    private func progressWidth(_ maxWidth: CGFloat) -> CGFloat {
        guard deps.playerVM.duration > 0 else { return 0 }
        let progress = isDragging ? dragValue : (deps.playerVM.currentTime / deps.playerVM.duration)
        return min(maxWidth * progress, maxWidth)
    }
    
    private func progressGesture(_ maxWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                let progress = max(0, min(value.location.x / maxWidth, 1))
                dragValue = progress
            }
            .onEnded { value in
                let progress = max(0, min(value.location.x / maxWidth, 1))
                deps.playerVM.seek(to: progress * deps.playerVM.duration)
                isDragging = false
            }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - FIXED: Main Controls ohne Overflow
struct MainControls: View {
    @EnvironmentObject var deps: AppDependencies
    
    var body: some View {
        HStack(spacing: 30) {
            // Shuffle
            Button { deps.playerVM.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 22))
                    .foregroundStyle(deps.playerVM.isShuffling ? .green : .white.opacity(0.7))
            }
            
            // Previous
            Button {
                Task { await deps.playerVM.playPrevious() }
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
            
            // Play/Pause
            Button {
                deps.playerVM.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 64, height: 64)
                    
                    if deps.playerVM.isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: deps.playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.black)
                            .offset(x: deps.playerVM.isPlaying ? 0 : 2)
                    }
                }
            }
            
            // Next
            Button {
                Task { await deps.playerVM.playNext() }
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
            
            // Repeat
            Button { deps.playerVM.toggleRepeat() } label: {
                Image(systemName: repeatIcon)
                    .font(.system(size: 22))
                    .foregroundStyle(repeatColor)
            }
        }
    }
    
    private var repeatIcon: String {
        switch deps.playerVM.repeatMode {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
    
    private var repeatColor: Color {
        switch deps.playerVM.repeatMode {
        case .off: return .white.opacity(0.7)
        case .all, .one: return .green
        }
    }
}

// MARK: - FIXED: Bottom Controls mit Audio Source
struct BottomControls: View {
    @EnvironmentObject var deps: AppDependencies
    let screenWidth: CGFloat
    
    var body: some View {
        HStack {
            AudioSourceButton(audioSessionManager: deps.audioSessionManager)
            
            Spacer()
        }
        .frame(maxWidth: screenWidth - 40)
        .padding(.horizontal, 20)
    }
}

// MARK: - Audio Source Button
struct AudioSourceButton: View {
    let audioSessionManager: AudioSessionManager
    
    var body: some View {
        ZStack {
            AudioRoutePickerViewRepresentable()
                .frame(width: 44, height: 44)
                .opacity(0.001)
            
            VStack(spacing: 4) {
                Image(systemName: audioSourceIcon)
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.7))
                
                Text(audioSourceText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
    
    private var audioSourceIcon: String {
        if audioSessionManager.isHeadphonesConnected {
            return "headphones"
        } else if audioSessionManager.audioRoute.contains("Bluetooth") {
            return "airpods"
        } else {
            return "speaker.wave.2"
        }
    }
    
    private var audioSourceText: String {
        if audioSessionManager.isHeadphonesConnected {
            return "Kopfhörer"
        } else if audioSessionManager.audioRoute.contains("Bluetooth") {
            return "Bluetooth"
        } else {
            return "iPhone"
        }
    }
}

// MARK: - AVRoutePickerView
struct AudioRoutePickerViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.backgroundColor = UIColor.clear
        routePickerView.tintColor = UIColor.white
        routePickerView.prioritizesVideoDevices = false
        return routePickerView
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
