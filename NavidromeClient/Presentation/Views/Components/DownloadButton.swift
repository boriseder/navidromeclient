import SwiftUI

struct DownloadButton: View {
    let album: Album
    let songs: [Song]
    let navidromeVM: NavidromeViewModel
    let playerVM: PlayerViewModel
    
    // @ObservedObject ist korrekt, da von Parent übergeben
    @ObservedObject var downloadManager: DownloadManager
    @State private var downloadState: DownloadState = .idle
    @State private var showingDeleteConfirmation = false
    
    private let buttonSize: CGFloat = 24

    enum DownloadState {
        case idle, downloading, downloaded, error, cancelling
    }

    private var isDownloading: Bool { downloadManager.isAlbumDownloading(album.id) }
    private var isDownloaded: Bool { downloadManager.isAlbumDownloaded(album.id) }
    private var progress: Double { downloadManager.downloadProgress[album.id] ?? 0 }
    
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
                downloadManager.deleteAlbum(albumId: album.id)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the downloaded songs from your device.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadCompleted)) { notification in
            if let completedAlbumId = notification.object as? String, completedAlbumId == album.id {
                withAnimation(.easeInOut(duration: 0.3)) {
                    downloadState = .downloaded
                }
            }
        }
        .onChange(of: isDownloading) { _, newValue in
            updateDownloadState()
        }
        .onChange(of: isDownloaded) { _, newValue in
            updateDownloadState()
        }
        .onChange(of: progress) { _, newValue in
            print("📊 Progress changed for \(album.id): \(newValue)")
        }
        .onAppear {
            updateDownloadState()
        }
    }
    
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
            case .error:
                errorButton
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
    
    private var errorButton: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 18))
            .foregroundColor(.orange)
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
    
    private func startDownload() {
        guard let service = navidromeVM.getService() else {
            downloadState = .error
            return
        }
        
        downloadState = .downloading
        
        Task {
            await downloadManager.downloadAlbum(
                songs: songs,
                albumId: album.id,
                service: service
            )
        }
    }
    
    private func cancelDownload() {
        downloadState = .cancelling
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            downloadState = .idle
        }
    }
    
    private func updateDownloadState() {
        if isDownloaded {
            downloadState = .downloaded
        } else if isDownloading {
            downloadState = .downloading
        } else if downloadState == .downloading {
            downloadState = isDownloaded ? .downloaded : .error
        } else if downloadState != .error {
            downloadState = .idle
        }
    }
}

