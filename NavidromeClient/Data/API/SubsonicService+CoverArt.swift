import UIKit

@MainActor
extension SubsonicService {
    func getCoverArt(for coverId: String, size: Int = 300) async -> UIImage? {
        let cacheKey = "\(coverId)_\(size)"
        
        // 1. Cache prüfen
        if let cached = PersistentImageCache.shared.image(for: cacheKey) {
            return cached
        }
        
        // 2. Von Server laden (ohne Request Deduplication in Extension)
        guard let url = buildURL(endpoint: "getCoverArt", params: ["id": coverId, "size": "\(size)"]) else {
            return nil
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data) else {
                return nil
            }
            
            // 3. In Cache speichern
            PersistentImageCache.shared.store(image, for: cacheKey)
            
            return image
            
        } catch {
            print("Cover art load error: \(error)")
            return nil
        }
    }
    
    func preloadCoverArt(for albums: [Album], size: Int = 200) async {
        for album in albums.prefix(5) { // Nur erste 5
            let cacheKey = "\(album.id)_\(size)"
            if PersistentImageCache.shared.image(for: cacheKey) == nil {
                _ = await getCoverArt(for: album.id, size: size)
            }
        }
    }
}
