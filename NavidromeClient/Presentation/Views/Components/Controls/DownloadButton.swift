//
//  DownloadButton.swift - FIXED: Reactive State & Clean Icons
//  NavidromeClient
//
//   FIXED: Reactive state observation with proper UI updates
//   CLEAN: Proper icon symbolism and proportions
//

import SwiftUI

struct DownloadButton: View {
    let album: Album
    let songs: [Song]
    let navidromeVM: NavidromeViewModel
    
    @EnvironmentObject var downloadManager: DownloadManager
    @State private var showingDeleteConfirmation = false
    
    // Direct state observation for reactivity
    @State private var currentState: DownloadManager.DownloadState = .idle
    @State private var currentProgress: Double = 0.0
    
    var body: some View {
        Button {
            handleButtonTap()
        } label: {
            buttonContent
        }
        .onAppear {
            updateState()
        }
        .onReceive(downloadManager.objectWillChange) { _ in
            updateState()
        }
        .confirmationDialog(
            "Delete Downloaded Album?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                downloadManager.deleteDownload(albumId: album.id)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the downloaded songs from your device.")
        }
    }
    
    // Manual state synchronization
    private func updateState() {
        currentState = downloadManager.getDownloadState(for: album.id)
        currentProgress = downloadManager.downloadProgress[album.id] ?? 0.0
    }
    
    // Fixed layout with consistent frame
    @ViewBuilder
    private var buttonContent: some View {
        HStack(spacing: 8) {
            // Consistent 20x20 frame for all states
            Group {
                switch currentState {
                case .idle:
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.system(size: 18, weight: .medium))
                case .downloading:
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 2)
                        
                        Circle()
                            .trim(from: 0, to: max(0.05, currentProgress))
                            .stroke(.white, lineWidth: 2)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.2), value: currentProgress)
                        
                        Text("\(Int(max(0.05, currentProgress) * 100))%")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(.white)
                    }
                case .downloaded:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                case .error:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18, weight: .medium))
                case .cancelling:
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(.white)
                }
            }
            .frame(width: 20, height: 20) // Consistent frame prevents layout shifts
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(buttonBackgroundColor)
        .clipShape(Capsule())
        .shadow(radius: 4)
    }
    
    // Centralized background color logic
    private var buttonBackgroundColor: Color {
        switch currentState {
        case .idle, .downloading: return .blue
        case .downloaded: return .green
        case .error: return .red
        case .cancelling: return .gray
        }
    }
    
    // MARK: - Action Handling
    
    private func handleButtonTap() {
        switch currentState {
        case .idle, .error:
            startDownload()
        case .downloading:
            cancelDownload()
        case .downloaded:
            showingDeleteConfirmation = true
        case .cancelling:
            break
        }
    }
    
    private func startDownload() {
        Task {
            await downloadManager.startDownload(
                album: album,
                songs: songs
            )
        }
    }
    
    private func cancelDownload() {
        downloadManager.cancelDownload(albumId: album.id)
    }
}
