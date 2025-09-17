//
//  DownloadButton.swift - REFACTORED to Pure UI
//  NavidromeClient
//
//  ✅ CLEAN: All state management moved to DownloadManager
//  ✅ REACTIVE: Uses centralized download state instead of local @State
//

import SwiftUI

struct DownloadButton: View {
    let album: Album
    let songs: [Song]
    let navidromeVM: NavidromeViewModel
    
    @EnvironmentObject var downloadManager: DownloadManager
    @State private var showingDeleteConfirmation = false
    
    private let buttonSize: CGFloat = 24
    
    private var downloadState: DownloadManager.DownloadState {
        downloadManager.getDownloadState(for: album.id)
    }
    
    private var progress: Double {
        downloadManager.downloadProgress[album.id] ?? 0
    }
    
    var body: some View {
        Button {
            handleButtonTap()
        } label: {
            buttonContent
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
    
    // MARK: - ✅ Pure UI Content
    
    @ViewBuilder
    private var buttonContent: some View {
        ZStack {
            switch downloadState {
            case .idle:
                idleButton
            case .downloading:
                downloadingButton
            case .downloaded:
                downloadedButton
            case .error(let message):
                errorButton(message: message)
            case .cancelling:
                cancellingButton
            }
        }
        .frame(width: buttonSize, height: buttonSize)
    }
    
    private var idleButton: some View {
        Image(systemName: "arrow.down.circle")
            .font(.system(size: 18))
            .foregroundColor(.blue)
    }
    
    private var downloadingButton: some View {
        ZStack {
            Circle()
                .stroke(.blue.opacity(0.3), lineWidth: 2)
            
            Circle()
                .trim(from: 0, to: max(0.05, progress))
                .stroke(.blue, lineWidth: 2)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.2), value: progress)
            
            Text("\(Int(max(0.05, progress) * 100))%")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.blue)
        }
    }
    
    private var downloadedButton: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 18))
            .foregroundColor(.green)
    }
    
    private func errorButton(message: String) -> some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 18))
            .foregroundColor(.orange)
            .help(message) // Show error on hover/long press
    }
    
    private var cancellingButton: some View {
        ZStack {
            Circle()
                .stroke(.gray.opacity(0.3), lineWidth: 2)
            
            ProgressView()
                .scaleEffect(0.7)
                .tint(.gray)
        }
    }
    
    // MARK: - ✅ Simple Action Handler
    
    private func handleButtonTap() {
        switch downloadState {
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
    
    // ✅ FOCUSED: Route through DownloadManager only (no direct service access)
    private func startDownload() {
        // ✅ ROUTE: DownloadManager handles service access internally
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
