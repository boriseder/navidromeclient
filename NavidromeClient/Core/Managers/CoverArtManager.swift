import Foundation

@MainActor
class CoverArtManager: ObservableObject {
    static let shared = CoverArtManager()
    
    // MARK: - State (unchanged)
    @Published private(set) var albumImages: [String: UIImage] = [:]
    @Published private(set) var artistImages: [String: UIImage] = [:]
    @Published private(set) var loadingStates: [String: Bool] = [:]
    @Published private(set) var errorStates: [String: String] = [:]
    
    // ✅ NEW: Focused service dependency
    private weak var mediaService: MediaService?
    
    // ✅ BACKWARDS COMPATIBLE: Keep old service reference
    private weak var legacyService: UnifiedSubsonicService?
    
    private let persistentCache = PersistentImageCache.shared
    
    private init() {}
    
    // MARK: - ✅ ENHANCED: Dual Configuration Support
    
    /// NEW: Configure with focused MediaService (preferred)
    func configure(mediaService: MediaService) {
        self.mediaService = mediaService
        print("✅ CoverArtManager configured with focused MediaService")
    }
    
    /// LEGACY: Configure with UnifiedSubsonicService (backwards compatible)
    func configure(service: UnifiedSubsonicService) {
        self.legacyService = service
        self.mediaService = service.getMediaService()
        print("✅ CoverArtManager configured with legacy service (extracted MediaService)")
    }
    
    // MARK: - ✅ ENHANCED: Smart Service Resolution
    
    private var activeMediaService: MediaService? {
        return mediaService ?? legacyService?.getMediaService()
    }
    
    // MARK: - ✅ ENHANCED: Image Loading with Batch Support
    
    func loadAlbumImage(album: Album, size: Int = 200, staggerIndex: Int = 0) async -> UIImage? {
        let stateKey = album.id
        
        // Return cached state if available
        if let cached = albumImages[stateKey] {
            return cached
        }
        
        // Check persistent cache
        let cacheKey = "album_\(album.id)_\(size)"
        if let cached = persistentCache.image(for: cacheKey) {
            albumImages[stateKey] = cached
            return cached
        }
        
        // Load from service
        guard let service = activeMediaService else {
            errorStates[stateKey] = "Media service not available"
            return nil
        }
        
        loadingStates[stateKey] = true
        defer { loadingStates[stateKey] = false }
        
        if let image = await service.getCoverArt(for: album.id, size: size) {
            albumImages[stateKey] = image
            errorStates.removeValue(forKey: stateKey)
            return image
        } else {
            errorStates[stateKey] = "Failed to load image"
            return nil
        }
    }
    
    /// ✅ NEW: Batch cover art loading for better performance
    func preloadAlbums(_ albums: [Album], size: Int = 200) async {
        guard let service = activeMediaService else { return }
        
        let items = albums.map { (id: $0.id, size: size) }
        let batchResults = await service.getCoverArtBatch(items: items, maxConcurrent: 5)
        
        // Update state with batch results
        for (albumId, image) in batchResults {
            if let album = albums.first(where: { $0.id == albumId }) {
                albumImages[album.id] = image
                loadingStates.removeValue(forKey: album.id)
                errorStates.removeValue(forKey: album.id)
            }
        }
        
        print("✅ Batch preloaded \(batchResults.count)/\(albums.count) album covers")
    }
    
    // MARK: - Rest of implementation unchanged...
    
    func getAlbumImage(for albumId: String, size: Int = 200) -> UIImage? {
        return albumImages[albumId]
    }
    
    func isLoadingImage(for key: String) -> Bool {
        return loadingStates[key] == true
    }
    
    func getImageError(for key: String) -> String? {
        return errorStates[key]
    }
    
    func clearMemoryCache() {
        albumImages.removeAll()
        artistImages.removeAll()
        loadingStates.removeAll()
        errorStates.removeAll()
        persistentCache.clearCache()
        print("🧹 Cleared all image caches")
    }
}
