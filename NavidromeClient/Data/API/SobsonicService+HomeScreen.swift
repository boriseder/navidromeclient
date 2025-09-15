import Foundation

@MainActor
extension SubsonicService {
    enum AlbumListType: String {
        case recent = "recent"
        case newest = "newest"
        case frequent = "frequent"
        case random = "random"
        case byGenre = "byGenre"
    }
    
    func getAlbumList(type: AlbumListType, size: Int = 20, offset: Int = 0) async throws -> [Album] {
        let params = ["type": type.rawValue, "size": "\(size)", "offset": "\(offset)"]
        
        // Explizite Typen für bessere Klarheit
        let emptyAlbumList = AlbumList(album: [])
        let emptyContainer = AlbumListContainer(albumList2: emptyAlbumList)
        let fallbackResponse = SubsonicResponse<AlbumListContainer>(subsonicResponse: emptyContainer)
        
        let decoded: SubsonicResponse<AlbumListContainer> = try await fetchDataWithFallback(
            endpoint: "getAlbumList2",
            params: params,
            type: SubsonicResponse<AlbumListContainer>.self,
            fallback: fallbackResponse
        )
        
        let albums = decoded.subsonicResponse.albumList2.album
        print("✅ Loaded \(albums.count) \(type.rawValue) albums")
        return albums
    }
    
    // Convenience methods für spezifische Typen
    func getRecentAlbums(size: Int = 20) async throws -> [Album] {
        return try await getAlbumList(type: .recent, size: size)
    }
    
    func getNewestAlbums(size: Int = 20) async throws -> [Album] {
        return try await getAlbumList(type: .newest, size: size)
    }
    
    func getFrequentAlbums(size: Int = 20) async throws -> [Album] {
        return try await getAlbumList(type: .frequent, size: size)
    }
    
    func getRandomAlbums(size: Int = 20) async throws -> [Album] {
        return try await getAlbumList(type: .random, size: size)
    }
}

// MARK: - Keine Extensions mehr nötig, da wir direkte Error-Behandlung verwenden
